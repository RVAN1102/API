# ZAP Scanning Report

ZAP by [Checkmarx](https://checkmarx.com/).


## Summary of Alerts

| Risk Level | Number of Alerts |
| --- | --- |
| High | 0 |
| Medium | 0 |
| Low | 2 |
| Informational | 7 |






## Alerts

| Name | Risk Level | Number of Instances |
| --- | --- | --- |
| Cross-Origin-Resource-Policy Header Missing or Invalid | Low | 4 |
| X-Content-Type-Options Header Missing | Low | 4 |
| A Client Error response code was returned by the server | Informational | 60 |
| Non-Storable Content | Informational | Systemic |
| Sec-Fetch-Dest Header is Missing | Informational | Systemic |
| Sec-Fetch-Mode Header is Missing | Informational | Systemic |
| Sec-Fetch-Site Header is Missing | Informational | Systemic |
| Sec-Fetch-User Header is Missing | Informational | Systemic |
| Storable and Cacheable Content | Informational | 4 |




## Alert Detail



### [ Cross-Origin-Resource-Policy Header Missing or Invalid ](https://www.zaproxy.org/docs/alerts/90004/)



##### Low (Medium)

### Description

Cross-Origin-Resource-Policy header is an opt-in header designed to counter side-channels attacks like Spectre. Resource should be specifically set as shareable amongst different origins.

* URL: http://localhost:8000/api/v1/admin/health
  * Node Name: `http://localhost:8000/api/v1/admin/health`
  * Method: `GET`
  * Parameter: `Cross-Origin-Resource-Policy`
  * Attack: ``
  * Evidence: ``
  * Other Info: ``
* URL: http://localhost:8000/api/v1/billing/health
  * Node Name: `http://localhost:8000/api/v1/billing/health`
  * Method: `GET`
  * Parameter: `Cross-Origin-Resource-Policy`
  * Attack: ``
  * Evidence: ``
  * Other Info: ``
* URL: http://localhost:8000/api/v1/orders/health
  * Node Name: `http://localhost:8000/api/v1/orders/health`
  * Method: `GET`
  * Parameter: `Cross-Origin-Resource-Policy`
  * Attack: ``
  * Evidence: ``
  * Other Info: ``
* URL: http://localhost:8000/api/v1/users/health
  * Node Name: `http://localhost:8000/api/v1/users/health`
  * Method: `GET`
  * Parameter: `Cross-Origin-Resource-Policy`
  * Attack: ``
  * Evidence: ``
  * Other Info: ``


Instances: 4

### Solution

Ensure that the application/web server sets the Cross-Origin-Resource-Policy header appropriately, and that it sets the Cross-Origin-Resource-Policy header to 'same-origin' for all web pages.
'same-site' is considered as less secured and should be avoided.
If resources must be shared, set the header to 'cross-origin'.
If possible, ensure that the end user uses a standards-compliant and modern web browser that supports the Cross-Origin-Resource-Policy header (https://caniuse.com/mdn-http_headers_cross-origin-resource-policy).

### Reference


* [ https://developer.mozilla.org/en-US/docs/Web/HTTP/Reference/Headers/Cross-Origin-Embedder-Policy ](https://developer.mozilla.org/en-US/docs/Web/HTTP/Reference/Headers/Cross-Origin-Embedder-Policy)


#### CWE Id: [ 693 ](https://cwe.mitre.org/data/definitions/693.html)


#### WASC Id: 14

#### Source ID: 3

### [ X-Content-Type-Options Header Missing ](https://www.zaproxy.org/docs/alerts/10021/)



##### Low (Medium)

### Description

The Anti-MIME-Sniffing header X-Content-Type-Options was not set to 'nosniff'. This allows older versions of Internet Explorer and Chrome to perform MIME-sniffing on the response body, potentially causing the response body to be interpreted and displayed as a content type other than the declared content type. Current (early 2014) and legacy versions of Firefox will use the declared content type (if one is set), rather than performing MIME-sniffing.

* URL: http://localhost:8000/api/v1/admin/health
  * Node Name: `http://localhost:8000/api/v1/admin/health`
  * Method: `GET`
  * Parameter: `x-content-type-options`
  * Attack: ``
  * Evidence: ``
  * Other Info: `This issue still applies to error type pages (401, 403, 500, etc.) as those pages are often still affected by injection issues, in which case there is still concern for browsers sniffing pages away from their actual content type.
At "High" threshold this scan rule will not alert on client or server error responses.`
* URL: http://localhost:8000/api/v1/billing/health
  * Node Name: `http://localhost:8000/api/v1/billing/health`
  * Method: `GET`
  * Parameter: `x-content-type-options`
  * Attack: ``
  * Evidence: ``
  * Other Info: `This issue still applies to error type pages (401, 403, 500, etc.) as those pages are often still affected by injection issues, in which case there is still concern for browsers sniffing pages away from their actual content type.
At "High" threshold this scan rule will not alert on client or server error responses.`
* URL: http://localhost:8000/api/v1/orders/health
  * Node Name: `http://localhost:8000/api/v1/orders/health`
  * Method: `GET`
  * Parameter: `x-content-type-options`
  * Attack: ``
  * Evidence: ``
  * Other Info: `This issue still applies to error type pages (401, 403, 500, etc.) as those pages are often still affected by injection issues, in which case there is still concern for browsers sniffing pages away from their actual content type.
At "High" threshold this scan rule will not alert on client or server error responses.`
* URL: http://localhost:8000/api/v1/users/health
  * Node Name: `http://localhost:8000/api/v1/users/health`
  * Method: `GET`
  * Parameter: `x-content-type-options`
  * Attack: ``
  * Evidence: ``
  * Other Info: `This issue still applies to error type pages (401, 403, 500, etc.) as those pages are often still affected by injection issues, in which case there is still concern for browsers sniffing pages away from their actual content type.
At "High" threshold this scan rule will not alert on client or server error responses.`


Instances: 4

### Solution

Ensure that the application/web server sets the Content-Type header appropriately, and that it sets the X-Content-Type-Options header to 'nosniff' for all web pages.
If possible, ensure that the end user uses a standards-compliant and modern web browser that does not perform MIME-sniffing at all, or that can be directed by the web application/web server to not perform MIME-sniffing.

### Reference


* [ https://learn.microsoft.com/en-us/previous-versions/windows/internet-explorer/ie-developer/compatibility/gg622941(v=vs.85) ](https://learn.microsoft.com/en-us/previous-versions/windows/internet-explorer/ie-developer/compatibility/gg622941(v=vs.85))
* [ https://owasp.org/www-community/Security_Headers ](https://owasp.org/www-community/Security_Headers)


#### CWE Id: [ 693 ](https://cwe.mitre.org/data/definitions/693.html)


#### WASC Id: 15

#### Source ID: 3

### [ A Client Error response code was returned by the server ](https://www.zaproxy.org/docs/alerts/100000/)



##### Informational (High)

### Description

A response code of 403 was returned by the server.
This may indicate that the application is failing to handle unexpected input correctly.
Raised by the 'Alert on HTTP Response Code Error' script

* URL: http://localhost:8000
  * Node Name: `http://localhost:8000`
  * Method: `GET`
  * Parameter: ``
  * Attack: ``
  * Evidence: `404`
  * Other Info: ``
* URL: http://localhost:8000/
  * Node Name: `http://localhost:8000/`
  * Method: `GET`
  * Parameter: ``
  * Attack: ``
  * Evidence: `404`
  * Other Info: ``
* URL: http://localhost:8000/5229812978343309281
  * Node Name: `http://localhost:8000/5229812978343309281`
  * Method: `GET`
  * Parameter: ``
  * Attack: ``
  * Evidence: `404`
  * Other Info: ``
* URL: http://localhost:8000/api
  * Node Name: `http://localhost:8000/api`
  * Method: `GET`
  * Parameter: ``
  * Attack: ``
  * Evidence: `404`
  * Other Info: ``
* URL: http://localhost:8000/api/
  * Node Name: `http://localhost:8000/api/`
  * Method: `GET`
  * Parameter: ``
  * Attack: ``
  * Evidence: `404`
  * Other Info: ``
* URL: http://localhost:8000/api/3266248030183945495
  * Node Name: `http://localhost:8000/api/3266248030183945495`
  * Method: `GET`
  * Parameter: ``
  * Attack: ``
  * Evidence: `404`
  * Other Info: ``
* URL: http://localhost:8000/api/v1
  * Node Name: `http://localhost:8000/api/v1`
  * Method: `GET`
  * Parameter: ``
  * Attack: ``
  * Evidence: `404`
  * Other Info: ``
* URL: http://localhost:8000/api/v1/
  * Node Name: `http://localhost:8000/api/v1/`
  * Method: `GET`
  * Parameter: ``
  * Attack: ``
  * Evidence: `404`
  * Other Info: ``
* URL: http://localhost:8000/api/v1/8781942358330379357
  * Node Name: `http://localhost:8000/api/v1/8781942358330379357`
  * Method: `GET`
  * Parameter: ``
  * Attack: ``
  * Evidence: `404`
  * Other Info: ``
* URL: http://localhost:8000/api/v1/admin
  * Node Name: `http://localhost:8000/api/v1/admin`
  * Method: `GET`
  * Parameter: ``
  * Attack: ``
  * Evidence: `404`
  * Other Info: ``
* URL: http://localhost:8000/api/v1/admin
  * Node Name: `http://localhost:8000/api/v1/admin`
  * Method: `GET`
  * Parameter: ``
  * Attack: ``
  * Evidence: `429`
  * Other Info: ``
* URL: http://localhost:8000/api/v1/admin/
  * Node Name: `http://localhost:8000/api/v1/admin/`
  * Method: `GET`
  * Parameter: ``
  * Attack: ``
  * Evidence: `429`
  * Other Info: ``
* URL: http://localhost:8000/api/v1/admin/4007812227501452039
  * Node Name: `http://localhost:8000/api/v1/admin/4007812227501452039`
  * Method: `GET`
  * Parameter: ``
  * Attack: ``
  * Evidence: `404`
  * Other Info: ``
* URL: http://localhost:8000/api/v1/admin/actuator/health
  * Node Name: `http://localhost:8000/api/v1/admin/actuator/health`
  * Method: `GET`
  * Parameter: ``
  * Attack: ``
  * Evidence: `429`
  * Other Info: ``
* URL: http://localhost:8000/api/v1/billing
  * Node Name: `http://localhost:8000/api/v1/billing`
  * Method: `GET`
  * Parameter: ``
  * Attack: ``
  * Evidence: `404`
  * Other Info: ``
* URL: http://localhost:8000/api/v1/billing
  * Node Name: `http://localhost:8000/api/v1/billing`
  * Method: `GET`
  * Parameter: ``
  * Attack: ``
  * Evidence: `429`
  * Other Info: ``
* URL: http://localhost:8000/api/v1/billing/
  * Node Name: `http://localhost:8000/api/v1/billing/`
  * Method: `GET`
  * Parameter: ``
  * Attack: ``
  * Evidence: `429`
  * Other Info: ``
* URL: http://localhost:8000/api/v1/billing/3026730012853599911
  * Node Name: `http://localhost:8000/api/v1/billing/3026730012853599911`
  * Method: `GET`
  * Parameter: ``
  * Attack: ``
  * Evidence: `404`
  * Other Info: ``
* URL: http://localhost:8000/api/v1/orders
  * Node Name: `http://localhost:8000/api/v1/orders`
  * Method: `GET`
  * Parameter: ``
  * Attack: ``
  * Evidence: `403`
  * Other Info: ``
* URL: http://localhost:8000/api/v1/orders/
  * Node Name: `http://localhost:8000/api/v1/orders/`
  * Method: `GET`
  * Parameter: ``
  * Attack: ``
  * Evidence: `429`
  * Other Info: ``
* URL: http://localhost:8000/api/v1/orders/4000001566402305290
  * Node Name: `http://localhost:8000/api/v1/orders/4000001566402305290`
  * Method: `GET`
  * Parameter: ``
  * Attack: ``
  * Evidence: `403`
  * Other Info: ``
* URL: http://localhost:8000/api/v1/orders/internal
  * Node Name: `http://localhost:8000/api/v1/orders/internal`
  * Method: `GET`
  * Parameter: ``
  * Attack: ``
  * Evidence: `429`
  * Other Info: ``
* URL: http://localhost:8000/api/v1/orders/internal/
  * Node Name: `http://localhost:8000/api/v1/orders/internal/`
  * Method: `GET`
  * Parameter: ``
  * Attack: ``
  * Evidence: `429`
  * Other Info: ``
* URL: http://localhost:8000/api/v1/orders/internal/4201134461270040261
  * Node Name: `http://localhost:8000/api/v1/orders/internal/4201134461270040261`
  * Method: `GET`
  * Parameter: ``
  * Attack: ``
  * Evidence: `404`
  * Other Info: ``
* URL: http://localhost:8000/api/v1/orders/ord-alice-1001
  * Node Name: `http://localhost:8000/api/v1/orders/ord-alice-1001`
  * Method: `GET`
  * Parameter: ``
  * Attack: ``
  * Evidence: `403`
  * Other Info: ``
* URL: http://localhost:8000/api/v1/orders/ord-alice-1001/
  * Node Name: `http://localhost:8000/api/v1/orders/ord-alice-1001/`
  * Method: `GET`
  * Parameter: ``
  * Attack: ``
  * Evidence: `429`
  * Other Info: ``
* URL: http://localhost:8000/api/v1/orders/ord-alice-1001/5765114180886680961
  * Node Name: `http://localhost:8000/api/v1/orders/ord-alice-1001/5765114180886680961`
  * Method: `GET`
  * Parameter: ``
  * Attack: ``
  * Evidence: `404`
  * Other Info: ``
* URL: http://localhost:8000/api/v1/orders/ord-alice-1001/fixed
  * Node Name: `http://localhost:8000/api/v1/orders/ord-alice-1001/fixed`
  * Method: `GET`
  * Parameter: ``
  * Attack: ``
  * Evidence: `403`
  * Other Info: ``
* URL: http://localhost:8000/api/v1/orders/ord-alice-1001/fixed/
  * Node Name: `http://localhost:8000/api/v1/orders/ord-alice-1001/fixed/`
  * Method: `GET`
  * Parameter: ``
  * Attack: ``
  * Evidence: `429`
  * Other Info: ``
* URL: http://localhost:8000/api/v1/orders/ord-bob-2001
  * Node Name: `http://localhost:8000/api/v1/orders/ord-bob-2001`
  * Method: `GET`
  * Parameter: ``
  * Attack: ``
  * Evidence: `429`
  * Other Info: ``
* URL: http://localhost:8000/api/v1/orders/ord-bob-2001/
  * Node Name: `http://localhost:8000/api/v1/orders/ord-bob-2001/`
  * Method: `GET`
  * Parameter: ``
  * Attack: ``
  * Evidence: `429`
  * Other Info: ``
* URL: http://localhost:8000/api/v1/orders/ord-bob-2001/691074649565276629
  * Node Name: `http://localhost:8000/api/v1/orders/ord-bob-2001/691074649565276629`
  * Method: `GET`
  * Parameter: ``
  * Attack: ``
  * Evidence: `404`
  * Other Info: ``
* URL: http://localhost:8000/api/v1/orders/ord-bob-2001/vulnerable
  * Node Name: `http://localhost:8000/api/v1/orders/ord-bob-2001/vulnerable`
  * Method: `GET`
  * Parameter: ``
  * Attack: ``
  * Evidence: `403`
  * Other Info: ``
* URL: http://localhost:8000/api/v1/orders/ord-bob-2001/vulnerable/
  * Node Name: `http://localhost:8000/api/v1/orders/ord-bob-2001/vulnerable/`
  * Method: `GET`
  * Parameter: ``
  * Attack: ``
  * Evidence: `429`
  * Other Info: ``
* URL: http://localhost:8000/api/v1/users
  * Node Name: `http://localhost:8000/api/v1/users`
  * Method: `GET`
  * Parameter: ``
  * Attack: ``
  * Evidence: `404`
  * Other Info: ``
* URL: http://localhost:8000/api/v1/users
  * Node Name: `http://localhost:8000/api/v1/users`
  * Method: `GET`
  * Parameter: ``
  * Attack: ``
  * Evidence: `429`
  * Other Info: ``
* URL: http://localhost:8000/api/v1/users/
  * Node Name: `http://localhost:8000/api/v1/users/`
  * Method: `GET`
  * Parameter: ``
  * Attack: ``
  * Evidence: `429`
  * Other Info: ``
* URL: http://localhost:8000/api/v1/users/7406146115447455904
  * Node Name: `http://localhost:8000/api/v1/users/7406146115447455904`
  * Method: `GET`
  * Parameter: ``
  * Attack: ``
  * Evidence: `404`
  * Other Info: ``
* URL: http://localhost:8000/api/v1/users/me
  * Node Name: `http://localhost:8000/api/v1/users/me`
  * Method: `GET`
  * Parameter: ``
  * Attack: ``
  * Evidence: `403`
  * Other Info: ``
* URL: http://localhost:8000/api/v1/users/profile
  * Node Name: `http://localhost:8000/api/v1/users/profile`
  * Method: `GET`
  * Parameter: ``
  * Attack: ``
  * Evidence: `403`
  * Other Info: ``
* URL: http://localhost:8000/api/v1/webhooks
  * Node Name: `http://localhost:8000/api/v1/webhooks`
  * Method: `GET`
  * Parameter: ``
  * Attack: ``
  * Evidence: `404`
  * Other Info: ``
* URL: http://localhost:8000/api/v1/webhooks/
  * Node Name: `http://localhost:8000/api/v1/webhooks/`
  * Method: `GET`
  * Parameter: ``
  * Attack: ``
  * Evidence: `404`
  * Other Info: ``
* URL: http://localhost:8000/api/v1/webhooks/8129936376887285665
  * Node Name: `http://localhost:8000/api/v1/webhooks/8129936376887285665`
  * Method: `GET`
  * Parameter: ``
  * Attack: ``
  * Evidence: `404`
  * Other Info: ``
* URL: http://localhost:8000/api/v1/admin/maintenance
  * Node Name: `http://localhost:8000/api/v1/admin/maintenance ()({action})`
  * Method: `POST`
  * Parameter: ``
  * Attack: ``
  * Evidence: `403`
  * Other Info: ``
* URL: http://localhost:8000/api/v1/admin/maintenance
  * Node Name: `http://localhost:8000/api/v1/admin/maintenance ()({action})`
  * Method: `POST`
  * Parameter: ``
  * Attack: ``
  * Evidence: `429`
  * Other Info: ``
* URL: http://localhost:8000/api/v1/admin/maintenance/
  * Node Name: `http://localhost:8000/api/v1/admin/maintenance/ ()({action})`
  * Method: `POST`
  * Parameter: ``
  * Attack: ``
  * Evidence: `429`
  * Other Info: ``
* URL: http://localhost:8000/api/v1/billing/checkout
  * Node Name: `http://localhost:8000/api/v1/billing/checkout ()({order_id,amount,currency})`
  * Method: `POST`
  * Parameter: ``
  * Attack: ``
  * Evidence: `403`
  * Other Info: ``
* URL: http://localhost:8000/api/v1/billing/checkout
  * Node Name: `http://localhost:8000/api/v1/billing/checkout ()({order_id,amount,currency})`
  * Method: `POST`
  * Parameter: ``
  * Attack: ``
  * Evidence: `429`
  * Other Info: ``
* URL: http://localhost:8000/api/v1/billing/checkout/
  * Node Name: `http://localhost:8000/api/v1/billing/checkout/ ()({order_id,amount,currency})`
  * Method: `POST`
  * Parameter: ``
  * Attack: ``
  * Evidence: `429`
  * Other Info: ``
* URL: http://localhost:8000/api/v1/orders/internal/verify-ownership
  * Node Name: `http://localhost:8000/api/v1/orders/internal/verify-ownership ()({order_id,subject})`
  * Method: `POST`
  * Parameter: ``
  * Attack: ``
  * Evidence: `403`
  * Other Info: ``
* URL: http://localhost:8000/api/v1/orders/internal/verify-ownership
  * Node Name: `http://localhost:8000/api/v1/orders/internal/verify-ownership ()({order_id,subject})`
  * Method: `POST`
  * Parameter: ``
  * Attack: ``
  * Evidence: `429`
  * Other Info: ``
* URL: http://localhost:8000/api/v1/orders/internal/verify-ownership/
  * Node Name: `http://localhost:8000/api/v1/orders/internal/verify-ownership/ ()({order_id,subject})`
  * Method: `POST`
  * Parameter: ``
  * Attack: ``
  * Evidence: `429`
  * Other Info: ``
* URL: http://localhost:8000/api/v1/webhooks/payment
  * Node Name: `http://localhost:8000/api/v1/webhooks/payment ()({event_id,event_type,checkout_id,amount})`
  * Method: `POST`
  * Parameter: ``
  * Attack: ``
  * Evidence: `401`
  * Other Info: ``
* URL: http://localhost:8000/computeMetadata/v1/
  * Node Name: `http://localhost:8000/computeMetadata/v1/ ()({action})`
  * Method: `POST`
  * Parameter: ``
  * Attack: ``
  * Evidence: `404`
  * Other Info: ``
* URL: http://localhost:8000/latest/meta-data/
  * Node Name: `http://localhost:8000/latest/meta-data/ ()({action})`
  * Method: `POST`
  * Parameter: ``
  * Attack: ``
  * Evidence: `404`
  * Other Info: ``
* URL: http://localhost:8000/metadata/instance
  * Node Name: `http://localhost:8000/metadata/instance ()({action})`
  * Method: `POST`
  * Parameter: ``
  * Attack: ``
  * Evidence: `404`
  * Other Info: ``
* URL: http://localhost:8000/metadata/v1
  * Node Name: `http://localhost:8000/metadata/v1 ()({action})`
  * Method: `POST`
  * Parameter: ``
  * Attack: ``
  * Evidence: `404`
  * Other Info: ``
* URL: http://localhost:8000/opc/v1/instance/
  * Node Name: `http://localhost:8000/opc/v1/instance/ ()({action})`
  * Method: `POST`
  * Parameter: ``
  * Attack: ``
  * Evidence: `404`
  * Other Info: ``
* URL: http://localhost:8000/opc/v2/instance/
  * Node Name: `http://localhost:8000/opc/v2/instance/ ()({action})`
  * Method: `POST`
  * Parameter: ``
  * Attack: ``
  * Evidence: `404`
  * Other Info: ``
* URL: http://localhost:8000/openstack/latest/meta_data.json
  * Node Name: `http://localhost:8000/openstack/latest/meta_data.json ()({action})`
  * Method: `POST`
  * Parameter: ``
  * Attack: ``
  * Evidence: `404`
  * Other Info: ``


Instances: 60

### Solution



### Reference



#### CWE Id: [ 388 ](https://cwe.mitre.org/data/definitions/388.html)


#### WASC Id: 20

#### Source ID: 4

### [ Non-Storable Content ](https://www.zaproxy.org/docs/alerts/10049/)



##### Informational (Medium)

### Description

The response contents are not storable by caching components such as proxy servers. If the response does not contain sensitive, personal or user-specific information, it may benefit from being stored and cached, to improve performance.

* URL: http://localhost:8000/api/v1/orders/ord-alice-1001
  * Node Name: `http://localhost:8000/api/v1/orders/ord-alice-1001`
  * Method: `GET`
  * Parameter: ``
  * Attack: ``
  * Evidence: `403`
  * Other Info: ``
* URL: http://localhost:8000/api/v1/orders/ord-alice-1001/fixed
  * Node Name: `http://localhost:8000/api/v1/orders/ord-alice-1001/fixed`
  * Method: `GET`
  * Parameter: ``
  * Attack: ``
  * Evidence: `403`
  * Other Info: ``
* URL: http://localhost:8000/api/v1/orders/ord-bob-2001/vulnerable
  * Node Name: `http://localhost:8000/api/v1/orders/ord-bob-2001/vulnerable`
  * Method: `GET`
  * Parameter: ``
  * Attack: ``
  * Evidence: `403`
  * Other Info: ``
* URL: http://localhost:8000/api/v1/users/me
  * Node Name: `http://localhost:8000/api/v1/users/me`
  * Method: `GET`
  * Parameter: ``
  * Attack: ``
  * Evidence: `403`
  * Other Info: ``
* URL: http://localhost:8000/api/v1/billing/checkout
  * Node Name: `http://localhost:8000/api/v1/billing/checkout ()({order_id,amount,currency})`
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

### [ Sec-Fetch-Dest Header is Missing ](https://www.zaproxy.org/docs/alerts/90005/)



##### Informational (High)

### Description

Specifies how and where the data would be used. For instance, if the value is audio, then the requested resource must be audio data and not any other type of resource.

* URL: http://localhost:8000/api/v1/orders
  * Node Name: `http://localhost:8000/api/v1/orders`
  * Method: `GET`
  * Parameter: `Sec-Fetch-Dest`
  * Attack: ``
  * Evidence: ``
  * Other Info: ``
* URL: http://localhost:8000/api/v1/orders/health
  * Node Name: `http://localhost:8000/api/v1/orders/health`
  * Method: `GET`
  * Parameter: `Sec-Fetch-Dest`
  * Attack: ``
  * Evidence: ``
  * Other Info: ``
* URL: http://localhost:8000/api/v1/orders/ord-alice-1001
  * Node Name: `http://localhost:8000/api/v1/orders/ord-alice-1001`
  * Method: `GET`
  * Parameter: `Sec-Fetch-Dest`
  * Attack: ``
  * Evidence: ``
  * Other Info: ``
* URL: http://localhost:8000/api/v1/users/me
  * Node Name: `http://localhost:8000/api/v1/users/me`
  * Method: `GET`
  * Parameter: `Sec-Fetch-Dest`
  * Attack: ``
  * Evidence: ``
  * Other Info: ``
* URL: http://localhost:8000/api/v1/billing/checkout
  * Node Name: `http://localhost:8000/api/v1/billing/checkout ()({order_id,amount,currency})`
  * Method: `POST`
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

* URL: http://localhost:8000/api/v1/orders
  * Node Name: `http://localhost:8000/api/v1/orders`
  * Method: `GET`
  * Parameter: `Sec-Fetch-Mode`
  * Attack: ``
  * Evidence: ``
  * Other Info: ``
* URL: http://localhost:8000/api/v1/orders/health
  * Node Name: `http://localhost:8000/api/v1/orders/health`
  * Method: `GET`
  * Parameter: `Sec-Fetch-Mode`
  * Attack: ``
  * Evidence: ``
  * Other Info: ``
* URL: http://localhost:8000/api/v1/orders/ord-alice-1001
  * Node Name: `http://localhost:8000/api/v1/orders/ord-alice-1001`
  * Method: `GET`
  * Parameter: `Sec-Fetch-Mode`
  * Attack: ``
  * Evidence: ``
  * Other Info: ``
* URL: http://localhost:8000/api/v1/users/me
  * Node Name: `http://localhost:8000/api/v1/users/me`
  * Method: `GET`
  * Parameter: `Sec-Fetch-Mode`
  * Attack: ``
  * Evidence: ``
  * Other Info: ``
* URL: http://localhost:8000/api/v1/billing/checkout
  * Node Name: `http://localhost:8000/api/v1/billing/checkout ()({order_id,amount,currency})`
  * Method: `POST`
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

* URL: http://localhost:8000/api/v1/orders
  * Node Name: `http://localhost:8000/api/v1/orders`
  * Method: `GET`
  * Parameter: `Sec-Fetch-Site`
  * Attack: ``
  * Evidence: ``
  * Other Info: ``
* URL: http://localhost:8000/api/v1/orders/health
  * Node Name: `http://localhost:8000/api/v1/orders/health`
  * Method: `GET`
  * Parameter: `Sec-Fetch-Site`
  * Attack: ``
  * Evidence: ``
  * Other Info: ``
* URL: http://localhost:8000/api/v1/orders/ord-alice-1001
  * Node Name: `http://localhost:8000/api/v1/orders/ord-alice-1001`
  * Method: `GET`
  * Parameter: `Sec-Fetch-Site`
  * Attack: ``
  * Evidence: ``
  * Other Info: ``
* URL: http://localhost:8000/api/v1/users/me
  * Node Name: `http://localhost:8000/api/v1/users/me`
  * Method: `GET`
  * Parameter: `Sec-Fetch-Site`
  * Attack: ``
  * Evidence: ``
  * Other Info: ``
* URL: http://localhost:8000/api/v1/billing/checkout
  * Node Name: `http://localhost:8000/api/v1/billing/checkout ()({order_id,amount,currency})`
  * Method: `POST`
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

* URL: http://localhost:8000/api/v1/orders
  * Node Name: `http://localhost:8000/api/v1/orders`
  * Method: `GET`
  * Parameter: `Sec-Fetch-User`
  * Attack: ``
  * Evidence: ``
  * Other Info: ``
* URL: http://localhost:8000/api/v1/orders/health
  * Node Name: `http://localhost:8000/api/v1/orders/health`
  * Method: `GET`
  * Parameter: `Sec-Fetch-User`
  * Attack: ``
  * Evidence: ``
  * Other Info: ``
* URL: http://localhost:8000/api/v1/orders/ord-alice-1001
  * Node Name: `http://localhost:8000/api/v1/orders/ord-alice-1001`
  * Method: `GET`
  * Parameter: `Sec-Fetch-User`
  * Attack: ``
  * Evidence: ``
  * Other Info: ``
* URL: http://localhost:8000/api/v1/users/me
  * Node Name: `http://localhost:8000/api/v1/users/me`
  * Method: `GET`
  * Parameter: `Sec-Fetch-User`
  * Attack: ``
  * Evidence: ``
  * Other Info: ``
* URL: http://localhost:8000/api/v1/billing/checkout
  * Node Name: `http://localhost:8000/api/v1/billing/checkout ()({order_id,amount,currency})`
  * Method: `POST`
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

* URL: http://localhost:8000/api/v1/admin/health
  * Node Name: `http://localhost:8000/api/v1/admin/health`
  * Method: `GET`
  * Parameter: ``
  * Attack: ``
  * Evidence: ``
  * Other Info: `In the absence of an explicitly specified caching lifetime directive in the response, a liberal lifetime heuristic of 1 year was assumed. This is permitted by rfc7234.`
* URL: http://localhost:8000/api/v1/billing/health
  * Node Name: `http://localhost:8000/api/v1/billing/health`
  * Method: `GET`
  * Parameter: ``
  * Attack: ``
  * Evidence: ``
  * Other Info: `In the absence of an explicitly specified caching lifetime directive in the response, a liberal lifetime heuristic of 1 year was assumed. This is permitted by rfc7234.`
* URL: http://localhost:8000/api/v1/orders/health
  * Node Name: `http://localhost:8000/api/v1/orders/health`
  * Method: `GET`
  * Parameter: ``
  * Attack: ``
  * Evidence: ``
  * Other Info: `In the absence of an explicitly specified caching lifetime directive in the response, a liberal lifetime heuristic of 1 year was assumed. This is permitted by rfc7234.`
* URL: http://localhost:8000/api/v1/users/health
  * Node Name: `http://localhost:8000/api/v1/users/health`
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


