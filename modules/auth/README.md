## SSO OIDC Setup

After deploying the auth module, run these steps on the CloudOS host:

### 1. Allow local HTTP in Nextcloud
```
docker exec cloudos-nextcloud php occ config:system:set allow_local_remote_servers --value="true"
docker exec cloudos-nextcloud php occ config:app:set user_oidc allow_insecure_http --value="true"
```

### 2. Create OIDC provider in Authentik
```
docker exec -i cloudos-authentik python3 /manage.py shell << "PYEOF"
from authentik.providers.oauth2.models import OAuth2Provider, ClientTypes, RedirectURI, RedirectURIMatchingMode
from authentik.core.models import Application
from authentik.flows.models import Flow
flow = Flow.objects.filter(designation="authorization").first()
uri1 = RedirectURI(matching_mode=RedirectURIMatchingMode.STRICT, url="http://100.79.173.91:8081/apps/user_oidc/code")
uri2 = RedirectURI(matching_mode=RedirectURIMatchingMode.STRICT, url="http://ubuntu:8081/apps/user_oidc/code")
p = OAuth2Provider.objects.create(name="Nextcloud", authorization_flow=flow, client_type=ClientTypes.CONFIDENTIAL, client_id="cloudos-nextcloud", redirect_uris=[uri1, uri2])
Application.objects.create(name="Nextcloud", slug="nextcloud", provider=p)
print("Secret:", p.client_secret)
PYEOF
```

### 3. Configure Nextcloud OIDC provider
```
docker exec cloudos-nextcloud php occ app:install user_oidc
docker exec cloudos-nextcloud php occ user_oidc:provider "cloudos-nextcloud" \
  --clientid="cloudos-nextcloud" \
  --clientsecret="<secret>" \
  --discoveryuri="http://cloudos-authentik:9000/application/o/nextcloud/.well-known/openid-configuration"
```

### 4. Login
- Direct URL: http://100.79.173.91:8081/apps/user_oidc/login/2
- Credentials: admin@cloudos.local / cloudos
