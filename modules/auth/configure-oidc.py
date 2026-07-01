#!/usr/bin/env python3
"""Configure Authentik OIDC provider for Nextcloud via Django ORM"""
import os, sys

os.environ.setdefault("DJANGO_SETTINGS_MODULE", "authentik.root.settings")

import django
django.setup()

from authentik.providers.oauth2.models import OAuth2Provider, ClientTypes
from authentik.core.models import Application
from authentik.flows.models import Flow

# 1. Get authorization flow
auth_flow = Flow.objects.filter(designation="authorization").first()
if not auth_flow:
    auth_flow = Flow.objects.filter(slug__icontains="authorize").first()

if not auth_flow:
    print("ERROR: No authorization flow found")
    sys.exit(1)

print("Auth flow:", auth_flow.slug)

# 2. Create OIDC provider
provider, created = OAuth2Provider.objects.get_or_create(
    name="Nextcloud",
    defaults={
        "authorization_flow": auth_flow,
        "client_type": ClientTypes.CONFIDENTIAL,
        "client_id": "cloudos-nextcloud",
        "redirect_uris": "http://100.79.173.91:8081/apps/user_oidc/callback\nhttp://ubuntu:8081/apps/user_oidc/callback",
        "token_validity": 3600,
    }
)
status = "CREATED" if created else "EXISTS"
print("OIDC Provider:", status)
print("  Client ID:", provider.client_id)
print("  Client Secret:", provider.client_secret)

# 3. Create Application
app, app_created = Application.objects.get_or_create(
    name="Nextcloud",
    defaults={
        "slug": "nextcloud",
        "provider": provider,
        "launch_url": "http://100.79.173.91:8081/",
    }
)
print("Application:", "CREATED" if app_created else "EXISTS")

# 4. Output config
print()
print("=" * 50)
print("Nextcloud OIDC Configuration")
print("=" * 50)
print()
print("Run on CloudOS host:")
print()
print("1. Install user_oidc app:")
print("  docker exec cloudos-nextcloud php occ app:install user_oidc")
print()
print("2. Configure OIDC provider:")
print(f"  docker exec cloudos-nextcloud php occ user_oidc:provider \\")
print(f"    --client-id=\"{provider.client_id}\" \\")
print(f"    --client-secret=\"{provider.client_secret}\" \\")
print(f"    --discovery-url=\"http://cloudos-authentik:9000/application/o/nextcloud/.well-known/openid-configuration\"")
print()
print("3. Verify:")
print("  docker exec cloudos-nextcloud php occ user_oidc:provider --list")
