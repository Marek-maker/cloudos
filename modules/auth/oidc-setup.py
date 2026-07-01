#!/usr/bin/env python3
"""Configure Authentik OIDC provider for Nextcloud.
Usage: docker exec cloudos-authentik python3 /tmp/ak-oidc-setup.py
"""
import os, sys, json, urllib.request

# ─── Configuration ───────────────────────────────────────────────────
AUTHENTIK_URL = "http://localhost:9000"
NEXTCLOUD_URL = "http://100.79.173.91:8081"
ADMIN_EMAIL = "admin@cloudos.local"
ADMIN_PASS = "cloudos"

# ─── Authentik API Helper ───────────────────────────────────────────
class AuthentikAPI:
    def __init__(self):
        self.token = None
        self._login()
    
    def _login(self):
        """Get JWT token via login"""
        data = json.dumps({"username": ADMIN_EMAIL, "password": ADMIN_PASS}).encode()
        req = urllib.request.Request(
            f"{AUTHENTIK_URL}/api/v3/authentication/login/",
            data=data,
            headers={"Content-Type": "application/json"}
        )
        try:
            resp = urllib.request.urlopen(req)
            # Authentik sets session cookie, but for API we need bearer token
            self.token = self._get_api_token()
        except urllib.error.HTTPError as e:
            print(f"Login failed: {e.code} {e.read().decode()[:200]}")
            sys.exit(1)
    
    def _get_api_token(self):
        """Create an API token for programmatic access"""
        data = json.dumps({
            "identifier": "cloudos-setup",
            "intent": "api",
        }).encode()
        req = urllib.request.Request(
            f"{AUTHENTIK_URL}/api/v3/authentik/core/tokens/",
            data=data,
            headers={"Content-Type": "application/json",
                     "Authorization": f"Bearer {self._get_admin_token()}"}
        )
        try:
            resp = urllib.request.urlopen(req)
            result = json.loads(resp.read())
            return result.get("key")
        except Exception as e:
            print(f"Token creation failed: {e}")
            return None
    
    def _get_admin_token(self):
        """Get initial admin token from credentials"""
        # This is complex - for now, we'll use a different approach
        return None
    
    def create_oidc_provider(self):
        """Create or get OIDC provider for Nextcloud"""
        # Get authorization flow
        flows = self.get("flows/instances/?designation=authorization")
        auth_flow = None
        for f in (flows or {}).get("results", []):
            if f.get("designation") == "authorization":
                auth_flow = f["pk"]
                break
        
        if not auth_flow:
            print("ERROR: No authorization flow found")
            return None
        
        # Create provider
        provider = self.post("providers/oauth2/", {
            "name": "Nextcloud",
            "authorization_flow": auth_flow,
            "client_type": "confidential",
            "client_id": "cloudos-nextcloud",
            "redirect_uris": f"{NEXTCLOUD_URL}/apps/user_oidc/callback\n"
                             f"http://ubuntu:8081/apps/user_oidc/callback",
        })
        return provider
    
    # ... API methods would continue here
    def get(self, path):
        return self._request("GET", path)
    
    def post(self, path, data):
        return self._request("POST", path, data)
    
    def _request(self, method, path, data=None):
        # TODO: implement with proper auth
        return None

# ─── Main ────────────────────────────────────────────────────────────
if __name__ == "__main__":
    print("=" * 50)
    print("CloudOS — Authentik OIDC Setup")
    print("=" * 50)
    print("\nNOTE: Full API integration requires running inside the")
    print("Authentik container or setting up proper API tokens.")
    print("\nFor manual setup:")
    print(f"  1. Open http://100.79.173.91:80/auth/")
    print(f"     Login: {ADMIN_EMAIL} / {ADMIN_PASS}")
    print(f"  2. Go to Admin → Applications → Providers → Create")
    print(f"     - Type: OAuth2/OpenID")
    print(f"     - Name: Nextcloud")
    print(f"     - Client ID: cloudos-nextcloud")
    print(f"     - Redirect URIs: {NEXTCLOUD_URL}/apps/user_oidc/callback")
    print(f"  3. Go to Admin → Applications → Create")
    print(f"     - Name: Nextcloud")
    print(f"     - Provider: Nextcloud (from step 2)")
    print(f"  4. In Nextcloud container:")
    print(f"     docker exec cloudos-nextcloud php occ app:install user_oidc")
    print(f"     docker exec cloudos-nextcloud php occ user_oidc:provider \\")
    print(f"       --client-id='cloudos-nextcloud' \\")
    print(f"       --client-secret='<from step 2>' \\")
    print(f"       --discovery-url='http://cloudos-authentik:9000/application/o/nextcloud/.well-known/openid-configuration'")
