# ZAP Scanning Report

ZAP by [Checkmarx](https://checkmarx.com/).


## Summary of Alerts

| Risk Level | Number of Alerts |
| --- | --- |
| High | 0 |
| Medium | 0 |
| Low | 0 |
| Informational | 8 |






## Alerts

| Name | Risk Level | Number of Instances |
| --- | --- | --- |
| A Client Error response code was returned by the server | Informational | 69 |
| Non-Storable Content | Informational | Systemic |
| Re-examine Cache-control Directives | Informational | 4 |
| Sec-Fetch-Dest Header is Missing | Informational | Systemic |
| Sec-Fetch-Mode Header is Missing | Informational | Systemic |
| Sec-Fetch-Site Header is Missing | Informational | Systemic |
| Sec-Fetch-User Header is Missing | Informational | Systemic |
| Storable and Cacheable Content | Informational | 4 |




## Alert Detail



### [ A Client Error response code was returned by the server ](https://www.zaproxy.org/docs/alerts/100000/)



##### Informational (High)

### Description

A response code of 403 was returned by the server.
This may indicate that the application is failing to handle unexpected input correctly.
Raised by the 'Alert on HTTP Response Code Error' script

* URL: https://localhost:8443
  * Node Name: `https://localhost:8443`
  * Method: `GET`
  * Parameter: ``
  * Attack: ``
  * Evidence: `404`
  * Other Info: ``
* URL: https://localhost:8443/
  * Node Name: `https://localhost:8443/`
  * Method: `GET`
  * Parameter: ``
  * Attack: ``
  * Evidence: `404`
  * Other Info: ``
* URL: https://localhost:8443/9110271128754953162
  * Node Name: `https://localhost:8443/9110271128754953162`
  * Method: `GET`
  * Parameter: ``
  * Attack: ``
  * Evidence: `404`
  * Other Info: ``
* URL: https://localhost:8443/api
  * Node Name: `https://localhost:8443/api`
  * Method: `GET`
  * Parameter: ``
  * Attack: ``
  * Evidence: `404`
  * Other Info: ``
* URL: https://localhost:8443/api/
  * Node Name: `https://localhost:8443/api/`
  * Method: `GET`
  * Parameter: ``
  * Attack: ``
  * Evidence: `404`
  * Other Info: ``
* URL: https://localhost:8443/api/6407155245287962704
  * Node Name: `https://localhost:8443/api/6407155245287962704`
  * Method: `GET`
  * Parameter: ``
  * Attack: ``
  * Evidence: `404`
  * Other Info: ``
* URL: https://localhost:8443/api/v1
  * Node Name: `https://localhost:8443/api/v1`
  * Method: `GET`
  * Parameter: ``
  * Attack: ``
  * Evidence: `404`
  * Other Info: ``
* URL: https://localhost:8443/api/v1/
  * Node Name: `https://localhost:8443/api/v1/`
  * Method: `GET`
  * Parameter: ``
  * Attack: ``
  * Evidence: `404`
  * Other Info: ``
* URL: https://localhost:8443/api/v1/4659318142404941187
  * Node Name: `https://localhost:8443/api/v1/4659318142404941187`
  * Method: `GET`
  * Parameter: ``
  * Attack: ``
  * Evidence: `404`
  * Other Info: ``
* URL: https://localhost:8443/api/v1/admin
  * Node Name: `https://localhost:8443/api/v1/admin`
  * Method: `GET`
  * Parameter: ``
  * Attack: ``
  * Evidence: `404`
  * Other Info: ``
* URL: https://localhost:8443/api/v1/admin
  * Node Name: `https://localhost:8443/api/v1/admin`
  * Method: `GET`
  * Parameter: ``
  * Attack: ``
  * Evidence: `429`
  * Other Info: ``
* URL: https://localhost:8443/api/v1/admin/
  * Node Name: `https://localhost:8443/api/v1/admin/`
  * Method: `GET`
  * Parameter: ``
  * Attack: ``
  * Evidence: `429`
  * Other Info: ``
* URL: https://localhost:8443/api/v1/admin/2427302101452251163
  * Node Name: `https://localhost:8443/api/v1/admin/2427302101452251163`
  * Method: `GET`
  * Parameter: ``
  * Attack: ``
  * Evidence: `404`
  * Other Info: ``
* URL: https://localhost:8443/api/v1/admin/actuator/health
  * Node Name: `https://localhost:8443/api/v1/admin/actuator/health`
  * Method: `GET`
  * Parameter: ``
  * Attack: ``
  * Evidence: `429`
  * Other Info: ``
* URL: https://localhost:8443/api/v1/admin/metadata-fetch
  * Node Name: `https://localhost:8443/api/v1/admin/metadata-fetch`
  * Method: `GET`
  * Parameter: ``
  * Attack: ``
  * Evidence: `429`
  * Other Info: ``
* URL: https://localhost:8443/api/v1/admin/metadata-fetch/
  * Node Name: `https://localhost:8443/api/v1/admin/metadata-fetch/`
  * Method: `GET`
  * Parameter: ``
  * Attack: ``
  * Evidence: `429`
  * Other Info: ``
* URL: https://localhost:8443/api/v1/admin/metadata-fetch/8859521118510908985
  * Node Name: `https://localhost:8443/api/v1/admin/metadata-fetch/8859521118510908985`
  * Method: `GET`
  * Parameter: ``
  * Attack: ``
  * Evidence: `404`
  * Other Info: ``
* URL: https://localhost:8443/api/v1/billing
  * Node Name: `https://localhost:8443/api/v1/billing`
  * Method: `GET`
  * Parameter: ``
  * Attack: ``
  * Evidence: `404`
  * Other Info: ``
* URL: https://localhost:8443/api/v1/billing
  * Node Name: `https://localhost:8443/api/v1/billing`
  * Method: `GET`
  * Parameter: ``
  * Attack: ``
  * Evidence: `429`
  * Other Info: ``
* URL: https://localhost:8443/api/v1/billing/
  * Node Name: `https://localhost:8443/api/v1/billing/`
  * Method: `GET`
  * Parameter: ``
  * Attack: ``
  * Evidence: `429`
  * Other Info: ``
* URL: https://localhost:8443/api/v1/billing/3429176457691808654
  * Node Name: `https://localhost:8443/api/v1/billing/3429176457691808654`
  * Method: `GET`
  * Parameter: ``
  * Attack: ``
  * Evidence: `404`
  * Other Info: ``
* URL: https://localhost:8443/api/v1/orders
  * Node Name: `https://localhost:8443/api/v1/orders`
  * Method: `GET`
  * Parameter: ``
  * Attack: ``
  * Evidence: `403`
  * Other Info: ``
* URL: https://localhost:8443/api/v1/orders/
  * Node Name: `https://localhost:8443/api/v1/orders/`
  * Method: `GET`
  * Parameter: ``
  * Attack: ``
  * Evidence: `429`
  * Other Info: ``
* URL: https://localhost:8443/api/v1/orders/2422477775691382571
  * Node Name: `https://localhost:8443/api/v1/orders/2422477775691382571`
  * Method: `GET`
  * Parameter: ``
  * Attack: ``
  * Evidence: `403`
  * Other Info: ``
* URL: https://localhost:8443/api/v1/orders/internal
  * Node Name: `https://localhost:8443/api/v1/orders/internal`
  * Method: `GET`
  * Parameter: ``
  * Attack: ``
  * Evidence: `429`
  * Other Info: ``
* URL: https://localhost:8443/api/v1/orders/internal/
  * Node Name: `https://localhost:8443/api/v1/orders/internal/`
  * Method: `GET`
  * Parameter: ``
  * Attack: ``
  * Evidence: `429`
  * Other Info: ``
* URL: https://localhost:8443/api/v1/orders/internal/4672256203508012039
  * Node Name: `https://localhost:8443/api/v1/orders/internal/4672256203508012039`
  * Method: `GET`
  * Parameter: ``
  * Attack: ``
  * Evidence: `404`
  * Other Info: ``
* URL: https://localhost:8443/api/v1/orders/ord-alice-1001
  * Node Name: `https://localhost:8443/api/v1/orders/ord-alice-1001`
  * Method: `GET`
  * Parameter: ``
  * Attack: ``
  * Evidence: `403`
  * Other Info: ``
* URL: https://localhost:8443/api/v1/orders/ord-alice-1001/
  * Node Name: `https://localhost:8443/api/v1/orders/ord-alice-1001/`
  * Method: `GET`
  * Parameter: ``
  * Attack: ``
  * Evidence: `429`
  * Other Info: ``
* URL: https://localhost:8443/api/v1/orders/ord-alice-1001/5501398106438246213
  * Node Name: `https://localhost:8443/api/v1/orders/ord-alice-1001/5501398106438246213`
  * Method: `GET`
  * Parameter: ``
  * Attack: ``
  * Evidence: `404`
  * Other Info: ``
* URL: https://localhost:8443/api/v1/orders/ord-alice-1001/fixed
  * Node Name: `https://localhost:8443/api/v1/orders/ord-alice-1001/fixed`
  * Method: `GET`
  * Parameter: ``
  * Attack: ``
  * Evidence: `403`
  * Other Info: ``
* URL: https://localhost:8443/api/v1/orders/ord-alice-1001/fixed/
  * Node Name: `https://localhost:8443/api/v1/orders/ord-alice-1001/fixed/`
  * Method: `GET`
  * Parameter: ``
  * Attack: ``
  * Evidence: `429`
  * Other Info: ``
* URL: https://localhost:8443/api/v1/orders/ord-bob-2001
  * Node Name: `https://localhost:8443/api/v1/orders/ord-bob-2001`
  * Method: `GET`
  * Parameter: ``
  * Attack: ``
  * Evidence: `429`
  * Other Info: ``
* URL: https://localhost:8443/api/v1/orders/ord-bob-2001/
  * Node Name: `https://localhost:8443/api/v1/orders/ord-bob-2001/`
  * Method: `GET`
  * Parameter: ``
  * Attack: ``
  * Evidence: `429`
  * Other Info: ``
* URL: https://localhost:8443/api/v1/orders/ord-bob-2001/2520761898802709589
  * Node Name: `https://localhost:8443/api/v1/orders/ord-bob-2001/2520761898802709589`
  * Method: `GET`
  * Parameter: ``
  * Attack: ``
  * Evidence: `404`
  * Other Info: ``
* URL: https://localhost:8443/api/v1/orders/ord-bob-2001/vulnerable
  * Node Name: `https://localhost:8443/api/v1/orders/ord-bob-2001/vulnerable`
  * Method: `GET`
  * Parameter: ``
  * Attack: ``
  * Evidence: `403`
  * Other Info: ``
* URL: https://localhost:8443/api/v1/orders/ord-bob-2001/vulnerable/
  * Node Name: `https://localhost:8443/api/v1/orders/ord-bob-2001/vulnerable/`
  * Method: `GET`
  * Parameter: ``
  * Attack: ``
  * Evidence: `429`
  * Other Info: ``
* URL: https://localhost:8443/api/v1/users
  * Node Name: `https://localhost:8443/api/v1/users`
  * Method: `GET`
  * Parameter: ``
  * Attack: ``
  * Evidence: `404`
  * Other Info: ``
* URL: https://localhost:8443/api/v1/users
  * Node Name: `https://localhost:8443/api/v1/users`
  * Method: `GET`
  * Parameter: ``
  * Attack: ``
  * Evidence: `429`
  * Other Info: ``
* URL: https://localhost:8443/api/v1/users/
  * Node Name: `https://localhost:8443/api/v1/users/`
  * Method: `GET`
  * Parameter: ``
  * Attack: ``
  * Evidence: `429`
  * Other Info: ``
* URL: https://localhost:8443/api/v1/users/4685032750965283460
  * Node Name: `https://localhost:8443/api/v1/users/4685032750965283460`
  * Method: `GET`
  * Parameter: ``
  * Attack: ``
  * Evidence: `404`
  * Other Info: ``
* URL: https://localhost:8443/api/v1/users/me
  * Node Name: `https://localhost:8443/api/v1/users/me`
  * Method: `GET`
  * Parameter: ``
  * Attack: ``
  * Evidence: `403`
  * Other Info: ``
* URL: https://localhost:8443/api/v1/users/profile
  * Node Name: `https://localhost:8443/api/v1/users/profile`
  * Method: `GET`
  * Parameter: ``
  * Attack: ``
  * Evidence: `403`
  * Other Info: ``
* URL: https://localhost:8443/api/v1/webhooks
  * Node Name: `https://localhost:8443/api/v1/webhooks`
  * Method: `GET`
  * Parameter: ``
  * Attack: ``
  * Evidence: `404`
  * Other Info: ``
* URL: https://localhost:8443/api/v1/webhooks/
  * Node Name: `https://localhost:8443/api/v1/webhooks/`
  * Method: `GET`
  * Parameter: ``
  * Attack: ``
  * Evidence: `404`
  * Other Info: ``
* URL: https://localhost:8443/api/v1/webhooks/4608633845527293829
  * Node Name: `https://localhost:8443/api/v1/webhooks/4608633845527293829`
  * Method: `GET`
  * Parameter: ``
  * Attack: ``
  * Evidence: `404`
  * Other Info: ``
* URL: https://localhost:8443/api/v1/admin/maintenance
  * Node Name: `https://localhost:8443/api/v1/admin/maintenance ()({action})`
  * Method: `POST`
  * Parameter: ``
  * Attack: ``
  * Evidence: `403`
  * Other Info: ``
* URL: https://localhost:8443/api/v1/admin/maintenance
  * Node Name: `https://localhost:8443/api/v1/admin/maintenance ()({action})`
  * Method: `POST`
  * Parameter: ``
  * Attack: ``
  * Evidence: `429`
  * Other Info: ``
* URL: https://localhost:8443/api/v1/admin/maintenance/
  * Node Name: `https://localhost:8443/api/v1/admin/maintenance/ ()({action})`
  * Method: `POST`
  * Parameter: ``
  * Attack: ``
  * Evidence: `429`
  * Other Info: ``
* URL: https://localhost:8443/api/v1/admin/metadata-fetch/fixed
  * Node Name: `https://localhost:8443/api/v1/admin/metadata-fetch/fixed ()({fetch_url})`
  * Method: `POST`
  * Parameter: ``
  * Attack: ``
  * Evidence: `403`
  * Other Info: ``
* URL: https://localhost:8443/api/v1/admin/metadata-fetch/fixed
  * Node Name: `https://localhost:8443/api/v1/admin/metadata-fetch/fixed ()({fetch_url})`
  * Method: `POST`
  * Parameter: ``
  * Attack: ``
  * Evidence: `429`
  * Other Info: ``
* URL: https://localhost:8443/api/v1/admin/metadata-fetch/fixed/
  * Node Name: `https://localhost:8443/api/v1/admin/metadata-fetch/fixed/ ()({fetch_url})`
  * Method: `POST`
  * Parameter: ``
  * Attack: ``
  * Evidence: `429`
  * Other Info: ``
* URL: https://localhost:8443/api/v1/admin/metadata-fetch/vulnerable
  * Node Name: `https://localhost:8443/api/v1/admin/metadata-fetch/vulnerable ()({fetch_url})`
  * Method: `POST`
  * Parameter: ``
  * Attack: ``
  * Evidence: `403`
  * Other Info: ``
* URL: https://localhost:8443/api/v1/admin/metadata-fetch/vulnerable
  * Node Name: `https://localhost:8443/api/v1/admin/metadata-fetch/vulnerable ()({fetch_url})`
  * Method: `POST`
  * Parameter: ``
  * Attack: ``
  * Evidence: `429`
  * Other Info: ``
* URL: https://localhost:8443/api/v1/admin/metadata-fetch/vulnerable/
  * Node Name: `https://localhost:8443/api/v1/admin/metadata-fetch/vulnerable/ ()({fetch_url})`
  * Method: `POST`
  * Parameter: ``
  * Attack: ``
  * Evidence: `429`
  * Other Info: ``
* URL: https://localhost:8443/api/v1/billing/checkout
  * Node Name: `https://localhost:8443/api/v1/billing/checkout ()({order_id,amount,currency})`
  * Method: `POST`
  * Parameter: ``
  * Attack: ``
  * Evidence: `403`
  * Other Info: ``
* URL: https://localhost:8443/api/v1/billing/checkout
  * Node Name: `https://localhost:8443/api/v1/billing/checkout ()({order_id,amount,currency})`
  * Method: `POST`
  * Parameter: ``
  * Attack: ``
  * Evidence: `429`
  * Other Info: ``
* URL: https://localhost:8443/api/v1/billing/checkout/
  * Node Name: `https://localhost:8443/api/v1/billing/checkout/ ()({order_id,amount,currency})`
  * Method: `POST`
  * Parameter: ``
  * Attack: ``
  * Evidence: `429`
  * Other Info: ``
* URL: https://localhost:8443/api/v1/orders/internal/verify-ownership
  * Node Name: `https://localhost:8443/api/v1/orders/internal/verify-ownership ()({order_id,subject})`
  * Method: `POST`
  * Parameter: ``
  * Attack: ``
  * Evidence: `403`
  * Other Info: ``
* URL: https://localhost:8443/api/v1/orders/internal/verify-ownership
  * Node Name: `https://localhost:8443/api/v1/orders/internal/verify-ownership ()({order_id,subject})`
  * Method: `POST`
  * Parameter: ``
  * Attack: ``
  * Evidence: `429`
  * Other Info: ``
* URL: https://localhost:8443/api/v1/orders/internal/verify-ownership/
  * Node Name: `https://localhost:8443/api/v1/orders/internal/verify-ownership/ ()({order_id,subject})`
  * Method: `POST`
  * Parameter: ``
  * Attack: ``
  * Evidence: `429`
  * Other Info: ``
* URL: https://localhost:8443/api/v1/webhooks/payment
  * Node Name: `https://localhost:8443/api/v1/webhooks/payment ()({event_id,event_type,checkout_id,amount})`
  * Method: `POST`
  * Parameter: ``
  * Attack: ``
  * Evidence: `401`
  * Other Info: ``
* URL: https://localhost:8443/computeMetadata/v1/
  * Node Name: `https://localhost:8443/computeMetadata/v1/ ()({action})`
  * Method: `POST`
  * Parameter: ``
  * Attack: ``
  * Evidence: `404`
  * Other Info: ``
* URL: https://localhost:8443/latest/meta-data/
  * Node Name: `https://localhost:8443/latest/meta-data/ ()({action})`
  * Method: `POST`
  * Parameter: ``
  * Attack: ``
  * Evidence: `404`
  * Other Info: ``
* URL: https://localhost:8443/metadata/instance
  * Node Name: `https://localhost:8443/metadata/instance ()({action})`
  * Method: `POST`
  * Parameter: ``
  * Attack: ``
  * Evidence: `404`
  * Other Info: ``
* URL: https://localhost:8443/metadata/v1
  * Node Name: `https://localhost:8443/metadata/v1 ()({action})`
  * Method: `POST`
  * Parameter: ``
  * Attack: ``
  * Evidence: `404`
  * Other Info: ``
* URL: https://localhost:8443/opc/v1/instance/
  * Node Name: `https://localhost:8443/opc/v1/instance/ ()({action})`
  * Method: `POST`
  * Parameter: ``
  * Attack: ``
  * Evidence: `404`
  * Other Info: ``
* URL: https://localhost:8443/opc/v2/instance/
  * Node Name: `https://localhost:8443/opc/v2/instance/ ()({action})`
  * Method: `POST`
  * Parameter: ``
  * Attack: ``
  * Evidence: `404`
  * Other Info: ``
* URL: https://localhost:8443/openstack/latest/meta_data.json
  * Node Name: `https://localhost:8443/openstack/latest/meta_data.json ()({action})`
  * Method: `POST`
  * Parameter: ``
  * Attack: ``
  * Evidence: `404`
  * Other Info: ``


Instances: 69

### Solution



### Reference



#### CWE Id: [ 388 ](https://cwe.mitre.org/data/definitions/388.html)


#### WASC Id: 20

#### Source ID: 4

### [ Non-Storable Content ](https://www.zaproxy.org/docs/alerts/10049/)



##### Informational (Medium)

### Description

The response contents are not storable by caching components such as proxy servers. If the response does not contain sensitive, personal or user-specific information, it may benefit from being stored and cached, to improve performance.

* URL: https://localhost:8443/api/v1/orders
  * Node Name: `https://localhost:8443/api/v1/orders`
  * Method: `GET`
  * Parameter: ``
  * Attack: ``
  * Evidence: `403`
  * Other Info: ``
* URL: https://localhost:8443/api/v1/orders/ord-bob-2001/vulnerable
  * Node Name: `https://localhost:8443/api/v1/orders/ord-bob-2001/vulnerable`
  * Method: `GET`
  * Parameter: ``
  * Attack: ``
  * Evidence: `403`
  * Other Info: ``
* URL: https://localhost:8443/api/v1/users/me
  * Node Name: `https://localhost:8443/api/v1/users/me`
  * Method: `GET`
  * Parameter: ``
  * Attack: ``
  * Evidence: `403`
  * Other Info: ``
* URL: https://localhost:8443/api/v1/users/profile
  * Node Name: `https://localhost:8443/api/v1/users/profile`
  * Method: `GET`
  * Parameter: ``
  * Attack: ``
  * Evidence: `403`
  * Other Info: ``
* URL: https://localhost:8443/api/v1/billing/checkout
  * Node Name: `https://localhost:8443/api/v1/billing/checkout ()({order_id,amount,currency})`
  * Method: `POST`
  * Parameter: ``
  * Attack: ``
  * Evidence: `403`
  * Other Info: ``

Instances: Systemic


### Solution

The content may be marked as storable by ensuring that the following conditions are satisfied:
The request method must be understood by the cache and defined as being cacheable ("GET", "HEAD", and "POST" are currently defined as cacheable)
The response status code must be understood by the cache (one of the 1XX, 2XX, 3XX, 4XX, or 5XX response classes are generally understood)
The "no-store" cache directive must not appear in the request or response header fields
For caching by "shared" caches such as "proxy" caches, the "private" response directive must not appear in the response
For caching by "shared" caches such as "proxy" caches, the "Authorization" header field must not appear in the request, unless the response explicitly allows it (using one of the "must-revalidate", "public", or "s-maxage" Cache-Control response directives)
In addition to the conditions above, at least one of the following conditions must also be satisfied by the response:
It must contain an "Expires" header field
It must contain a "max-age" response directive
For "shared" caches such as "proxy" caches, it must contain a "s-maxage" response directive
It must contain a "Cache Control Extension" that allows it to be cached
It must have a status code that is defined as cacheable by default (200, 203, 204, 206, 300, 301, 404, 405, 410, 414, 501).

### Reference


* [ https://datatracker.ietf.org/doc/html/rfc7234 ](https://datatracker.ietf.org/doc/html/rfc7234)
* [ https://datatracker.ietf.org/doc/html/rfc7231 ](https://datatracker.ietf.org/doc/html/rfc7231)
* [ https://www.w3.org/Protocols/rfc2616/rfc2616-sec13.html ](https://www.w3.org/Protocols/rfc2616/rfc2616-sec13.html)


#### CWE Id: [ 524 ](https://cwe.mitre.org/data/definitions/524.html)


#### WASC Id: 13

#### Source ID: 3

### [ Re-examine Cache-control Directives ](https://www.zaproxy.org/docs/alerts/10015/)



##### Informational (Low)

### Description

The cache-control header has not been set properly or is missing, allowing the browser and proxies to cache content. For static assets like css, js, or image files this might be intended, however, the resources should be reviewed to ensure that no sensitive content will be cached.

* URL: https://localhost:8443/api/v1/admin/health
  * Node Name: `https://localhost:8443/api/v1/admin/health`
  * Method: `GET`
  * Parameter: `cache-control`
  * Attack: ``
  * Evidence: ``
  * Other Info: ``
* URL: https://localhost:8443/api/v1/billing/health
  * Node Name: `https://localhost:8443/api/v1/billing/health`
  * Method: `GET`
  * Parameter: `cache-control`
  * Attack: ``
  * Evidence: ``
  * Other Info: ``
* URL: https://localhost:8443/api/v1/orders/health
  * Node Name: `https://localhost:8443/api/v1/orders/health`
  * Method: `GET`
  * Parameter: `cache-control`
  * Attack: ``
  * Evidence: ``
  * Other Info: ``
* URL: https://localhost:8443/api/v1/users/health
  * Node Name: `https://localhost:8443/api/v1/users/health`
  * Method: `GET`
  * Parameter: `cache-control`
  * Attack: ``
  * Evidence: ``
  * Other Info: ``


Instances: 4

### Solution

For secure content, ensure the cache-control HTTP header is set with "no-cache, no-store, must-revalidate". If an asset should be cached consider setting the directives "public, max-age, immutable".

### Reference


* [ https://cheatsheetseries.owasp.org/cheatsheets/Session_Management_Cheat_Sheet.html#web-content-caching ](https://cheatsheetseries.owasp.org/cheatsheets/Session_Management_Cheat_Sheet.html#web-content-caching)
* [ https://developer.mozilla.org/en-US/docs/Web/HTTP/Reference/Headers/Cache-Control ](https://developer.mozilla.org/en-US/docs/Web/HTTP/Reference/Headers/Cache-Control)
* [ https://grayduck.mn/2021/09/13/cache-control-recommendations/ ](https://grayduck.mn/2021/09/13/cache-control-recommendations/)


#### CWE Id: [ 525 ](https://cwe.mitre.org/data/definitions/525.html)


#### WASC Id: 13

#### Source ID: 3

### [ Sec-Fetch-Dest Header is Missing ](https://www.zaproxy.org/docs/alerts/90005/)



##### Informational (High)

### Description

Specifies how and where the data would be used. For instance, if the value is audio, then the requested resource must be audio data and not any other type of resource.

* URL: https://localhost:8443/api/v1/billing/health
  * Node Name: `https://localhost:8443/api/v1/billing/health`
  * Method: `GET`
  * Parameter: `Sec-Fetch-Dest`
  * Attack: ``
  * Evidence: ``
  * Other Info: ``
* URL: https://localhost:8443/api/v1/orders/ord-alice-1001
  * Node Name: `https://localhost:8443/api/v1/orders/ord-alice-1001`
  * Method: `GET`
  * Parameter: `Sec-Fetch-Dest`
  * Attack: ``
  * Evidence: ``
  * Other Info: ``
* URL: https://localhost:8443/api/v1/orders/ord-alice-1001/fixed
  * Node Name: `https://localhost:8443/api/v1/orders/ord-alice-1001/fixed`
  * Method: `GET`
  * Parameter: `Sec-Fetch-Dest`
  * Attack: ``
  * Evidence: ``
  * Other Info: ``
* URL: https://localhost:8443/api/v1/orders/ord-bob-2001/vulnerable
  * Node Name: `https://localhost:8443/api/v1/orders/ord-bob-2001/vulnerable`
  * Method: `GET`
  * Parameter: `Sec-Fetch-Dest`
  * Attack: ``
  * Evidence: ``
  * Other Info: ``
* URL: https://localhost:8443/api/v1/users/me
  * Node Name: `https://localhost:8443/api/v1/users/me`
  * Method: `GET`
  * Parameter: `Sec-Fetch-Dest`
  * Attack: ``
  * Evidence: ``
  * Other Info: ``

Instances: Systemic


### Solution

Ensure that Sec-Fetch-Dest header is included in request headers.

### Reference


* [ https://developer.mozilla.org/en-US/docs/Web/HTTP/Reference/Headers/Sec-Fetch-Dest ](https://developer.mozilla.org/en-US/docs/Web/HTTP/Reference/Headers/Sec-Fetch-Dest)


#### CWE Id: [ 352 ](https://cwe.mitre.org/data/definitions/352.html)


#### WASC Id: 9

#### Source ID: 3

### [ Sec-Fetch-Mode Header is Missing ](https://www.zaproxy.org/docs/alerts/90005/)



##### Informational (High)

### Description

Allows to differentiate between requests for navigating between HTML pages and requests for loading resources like images, audio etc.

* URL: https://localhost:8443/api/v1/admin/health
  * Node Name: `https://localhost:8443/api/v1/admin/health`
  * Method: `GET`
  * Parameter: `Sec-Fetch-Mode`
  * Attack: ``
  * Evidence: ``
  * Other Info: ``
* URL: https://localhost:8443/api/v1/billing/health
  * Node Name: `https://localhost:8443/api/v1/billing/health`
  * Method: `GET`
  * Parameter: `Sec-Fetch-Mode`
  * Attack: ``
  * Evidence: ``
  * Other Info: ``
* URL: https://localhost:8443/api/v1/orders
  * Node Name: `https://localhost:8443/api/v1/orders`
  * Method: `GET`
  * Parameter: `Sec-Fetch-Mode`
  * Attack: ``
  * Evidence: ``
  * Other Info: ``
* URL: https://localhost:8443/api/v1/orders/ord-bob-2001/vulnerable
  * Node Name: `https://localhost:8443/api/v1/orders/ord-bob-2001/vulnerable`
  * Method: `GET`
  * Parameter: `Sec-Fetch-Mode`
  * Attack: ``
  * Evidence: ``
  * Other Info: ``
* URL: https://localhost:8443/api/v1/users/me
  * Node Name: `https://localhost:8443/api/v1/users/me`
  * Method: `GET`
  * Parameter: `Sec-Fetch-Mode`
  * Attack: ``
  * Evidence: ``
  * Other Info: ``

Instances: Systemic


### Solution

Ensure that Sec-Fetch-Mode header is included in request headers.

### Reference


* [ https://developer.mozilla.org/en-US/docs/Web/HTTP/Reference/Headers/Sec-Fetch-Mode ](https://developer.mozilla.org/en-US/docs/Web/HTTP/Reference/Headers/Sec-Fetch-Mode)


#### CWE Id: [ 352 ](https://cwe.mitre.org/data/definitions/352.html)


#### WASC Id: 9

#### Source ID: 3

### [ Sec-Fetch-Site Header is Missing ](https://www.zaproxy.org/docs/alerts/90005/)



##### Informational (High)

### Description

Specifies the relationship between request initiator's origin and target's origin.

* URL: https://localhost:8443/api/v1/billing/health
  * Node Name: `https://localhost:8443/api/v1/billing/health`
  * Method: `GET`
  * Parameter: `Sec-Fetch-Site`
  * Attack: ``
  * Evidence: ``
  * Other Info: ``
* URL: https://localhost:8443/api/v1/orders/ord-alice-1001
  * Node Name: `https://localhost:8443/api/v1/orders/ord-alice-1001`
  * Method: `GET`
  * Parameter: `Sec-Fetch-Site`
  * Attack: ``
  * Evidence: ``
  * Other Info: ``
* URL: https://localhost:8443/api/v1/orders/ord-alice-1001/fixed
  * Node Name: `https://localhost:8443/api/v1/orders/ord-alice-1001/fixed`
  * Method: `GET`
  * Parameter: `Sec-Fetch-Site`
  * Attack: ``
  * Evidence: ``
  * Other Info: ``
* URL: https://localhost:8443/api/v1/orders/ord-bob-2001/vulnerable
  * Node Name: `https://localhost:8443/api/v1/orders/ord-bob-2001/vulnerable`
  * Method: `GET`
  * Parameter: `Sec-Fetch-Site`
  * Attack: ``
  * Evidence: ``
  * Other Info: ``
* URL: https://localhost:8443/api/v1/users/me
  * Node Name: `https://localhost:8443/api/v1/users/me`
  * Method: `GET`
  * Parameter: `Sec-Fetch-Site`
  * Attack: ``
  * Evidence: ``
  * Other Info: ``

Instances: Systemic


### Solution

Ensure that Sec-Fetch-Site header is included in request headers.

### Reference


* [ https://developer.mozilla.org/en-US/docs/Web/HTTP/Reference/Headers/Sec-Fetch-Site ](https://developer.mozilla.org/en-US/docs/Web/HTTP/Reference/Headers/Sec-Fetch-Site)


#### CWE Id: [ 352 ](https://cwe.mitre.org/data/definitions/352.html)


#### WASC Id: 9

#### Source ID: 3

### [ Sec-Fetch-User Header is Missing ](https://www.zaproxy.org/docs/alerts/90005/)



##### Informational (High)

### Description

Specifies if a navigation request was initiated by a user.

* URL: https://localhost:8443/api/v1/admin/health
  * Node Name: `https://localhost:8443/api/v1/admin/health`
  * Method: `GET`
  * Parameter: `Sec-Fetch-User`
  * Attack: ``
  * Evidence: ``
  * Other Info: ``
* URL: https://localhost:8443/api/v1/billing/health
  * Node Name: `https://localhost:8443/api/v1/billing/health`
  * Method: `GET`
  * Parameter: `Sec-Fetch-User`
  * Attack: ``
  * Evidence: ``
  * Other Info: ``
* URL: https://localhost:8443/api/v1/orders
  * Node Name: `https://localhost:8443/api/v1/orders`
  * Method: `GET`
  * Parameter: `Sec-Fetch-User`
  * Attack: ``
  * Evidence: ``
  * Other Info: ``
* URL: https://localhost:8443/api/v1/orders/ord-bob-2001/vulnerable
  * Node Name: `https://localhost:8443/api/v1/orders/ord-bob-2001/vulnerable`
  * Method: `GET`
  * Parameter: `Sec-Fetch-User`
  * Attack: ``
  * Evidence: ``
  * Other Info: ``
* URL: https://localhost:8443/api/v1/users/me
  * Node Name: `https://localhost:8443/api/v1/users/me`
  * Method: `GET`
  * Parameter: `Sec-Fetch-User`
  * Attack: ``
  * Evidence: ``
  * Other Info: ``

Instances: Systemic


### Solution

Ensure that Sec-Fetch-User header is included in user initiated requests.

### Reference


* [ https://developer.mozilla.org/en-US/docs/Web/HTTP/Reference/Headers/Sec-Fetch-User ](https://developer.mozilla.org/en-US/docs/Web/HTTP/Reference/Headers/Sec-Fetch-User)


#### CWE Id: [ 352 ](https://cwe.mitre.org/data/definitions/352.html)


#### WASC Id: 9

#### Source ID: 3

### [ Storable and Cacheable Content ](https://www.zaproxy.org/docs/alerts/10049/)



##### Informational (Medium)

### Description

The response contents are storable by caching components such as proxy servers, and may be retrieved directly from the cache, rather than from the origin server by the caching servers, in response to similar requests from other users. If the response data is sensitive, personal or user-specific, this may result in sensitive information being leaked. In some cases, this may even result in a user gaining complete control of the session of another user, depending on the configuration of the caching components in use in their environment. This is primarily an issue where "shared" caching servers such as "proxy" caches are configured on the local network. This configuration is typically found in corporate or educational environments, for instance.

* URL: https://localhost:8443/api/v1/admin/health
  * Node Name: `https://localhost:8443/api/v1/admin/health`
  * Method: `GET`
  * Parameter: ``
  * Attack: ``
  * Evidence: ``
  * Other Info: `In the absence of an explicitly specified caching lifetime directive in the response, a liberal lifetime heuristic of 1 year was assumed. This is permitted by rfc7234.`
* URL: https://localhost:8443/api/v1/billing/health
  * Node Name: `https://localhost:8443/api/v1/billing/health`
  * Method: `GET`
  * Parameter: ``
  * Attack: ``
  * Evidence: ``
  * Other Info: `In the absence of an explicitly specified caching lifetime directive in the response, a liberal lifetime heuristic of 1 year was assumed. This is permitted by rfc7234.`
* URL: https://localhost:8443/api/v1/orders/health
  * Node Name: `https://localhost:8443/api/v1/orders/health`
  * Method: `GET`
  * Parameter: ``
  * Attack: ``
  * Evidence: ``
  * Other Info: `In the absence of an explicitly specified caching lifetime directive in the response, a liberal lifetime heuristic of 1 year was assumed. This is permitted by rfc7234.`
* URL: https://localhost:8443/api/v1/users/health
  * Node Name: `https://localhost:8443/api/v1/users/health`
  * Method: `GET`
  * Parameter: ``
  * Attack: ``
  * Evidence: ``
  * Other Info: `In the absence of an explicitly specified caching lifetime directive in the response, a liberal lifetime heuristic of 1 year was assumed. This is permitted by rfc7234.`


Instances: 4

### Solution

Validate that the response does not contain sensitive, personal or user-specific information. If it does, consider the use of the following HTTP response headers, to limit, or prevent the content being stored and retrieved from the cache by another user:
Cache-Control: no-cache, no-store, must-revalidate, private
Pragma: no-cache
Expires: 0
This configuration directs both HTTP 1.0 and HTTP 1.1 compliant caching servers to not store the response, and to not retrieve the response (without validation) from the cache, in response to a similar request.

### Reference


* [ https://datatracker.ietf.org/doc/html/rfc7234 ](https://datatracker.ietf.org/doc/html/rfc7234)
* [ https://datatracker.ietf.org/doc/html/rfc7231 ](https://datatracker.ietf.org/doc/html/rfc7231)
* [ https://www.w3.org/Protocols/rfc2616/rfc2616-sec13.html ](https://www.w3.org/Protocols/rfc2616/rfc2616-sec13.html)


#### CWE Id: [ 524 ](https://cwe.mitre.org/data/definitions/524.html)


#### WASC Id: 13

#### Source ID: 3


