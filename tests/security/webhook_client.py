import sys
import ssl
import urllib.request
import urllib.error
import argparse

def main():
    parser = argparse.ArgumentParser(description='mTLS Webhook Test Client')
    parser.add_argument('--url', required=True)
    parser.add_argument('--cert', required=False)
    parser.add_argument('--key', required=False)
    parser.add_argument('--data', required=False)
    parser.add_argument('--header', action='append', default=[])
    args = parser.parse_args()

    context = ssl.create_default_context()
    context.check_hostname = False
    context.verify_mode = ssl.CERT_NONE

    if args.cert and args.key:
        try:
            context.load_cert_chain(certfile=args.cert, keyfile=args.key)
        except Exception as e:
            print(f"Error loading cert: {e}", file=sys.stderr)
            sys.exit(1)

    req = urllib.request.Request(args.url, method="POST")
    for h in args.header:
        if ':' in h:
            k, v = h.split(':', 1)
            req.add_header(k.strip(), v.strip())
            
    data = args.data.encode('utf-8') if args.data else b''
    
    try:
        response = urllib.request.urlopen(req, data=data, context=context)
        print(response.getcode())
    except urllib.error.HTTPError as e:
        print(e.code)
    except urllib.error.URLError as e:
        print(f"000\nURLError: {e}", file=sys.stderr)
    except Exception as e:
        print(f"000\nException: {e}", file=sys.stderr)

if __name__ == '__main__':
    main()
