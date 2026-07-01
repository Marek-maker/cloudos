#!/usr/bin/env -S python3 /manage.py shell
"""Configure Authentik OIDC provider for Nextcloud.
Run inside Authentik container: python3 /tmp/setup.py
"""
from authentik.providers.oauth2.models import OAuth2Provider, ClientTypes
from authentik.core.models import Application
from authentik.flows.models import Flow

# 1. Get authorization flow
auth_flow = Flow.objects.filter(designation="authorization").first()
print("Auth flow:", auth_flow.slug if auth_flow else "NONE")

# 2. Create OIDC provider
provider = OAuth2Provider.objects.create(
    name="Nextcloud",
    authorization_flow=auth_flow,
    client_type=ClientTypes.CONFIDENTIAL,
    client_id="cloudos-nextcloud",
    redirect_uris="http://100.79.173.91:8081/apps/user_oidc/callback\nhttp://ubuntu:8081/apps/user_oidc/callback",
)
print("Provider created:", provider.name)
print("  Client ID:", provider.client_id)
print("  Client Secret:", provider.client_secret)

# 3. Create Application
app = Application.objects.create(
    name="Nextcloud",
    slug="nextcloud",
    provider=provider,
)
print("Application created:", app.name)

# 4. Output config
print()
print("=== Nextcloud OIDC Configuration ===")
print(f"Run: docker exec cloudos-nextcloud php occ app:install user_oidc")
print(f"Run: docker exec cloudos-nextcloud php occ user_oidc:provider --client-id=\"{provider.client_id}\" --client-secret=\"{provider.client_secret}\" --discovery-url=\"http://cloudos-authentik:9000/application/o/nextcloud/.well-known/openid-configuration\"")
