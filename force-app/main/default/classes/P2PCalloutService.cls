/**
 * P2PCalloutService — Generic point-to-point HTTPS callout utility
 * Creates HttpRequest and executes callout to any desired API.
 * Usage:
 *   HttpResponse res = P2PCalloutService.get('https://hacker-news.firebaseio.com/v0/topstories.json');
 *   HttpResponse res2 = P2PCalloutService.post('https://api.example.com/v1/data', JSON.serialize(payload), headers);
 *   // Builder style:
 *   P2PCalloutService.CalloutConfig cfg = new P2PCalloutService.CalloutConfig('https://api.example.com/v1/items')
 *       .setMethod('GET')
 *       .setHeaders(new Map<String,String>{'Authorization'=>'Bearer token'})
 *       .setTimeout(10000)
 *       .setQueryParams(new Map<String,String>{'limit'=>'10'});
 *   HttpResponse res3 = P2PCalloutService.send(cfg);
 */
public with sharing class P2PCalloutService {

    public class P2PCalloutException extends Exception {}

    // Fluent config for building a request
    public class CalloutConfig {
        public String endpoint { get; private set; }
        public String method { get; private set; }
        public Map<String, String> headers { get; private set; }
        public Map<String, String> queryParams { get; private set; }
        public String body { get; private set; }
        public Integer timeoutMs { get; private set; }
        public Boolean compressed { get; private set; }
        public String clientCertName { get; private set; }

        public CalloutConfig(String endpoint) {
            if (String.isBlank(endpoint)) {
                throw new P2PCalloutException('Endpoint cannot be blank');
            }
            this.endpoint = endpoint;
            this.method = 'GET';
            this.headers = new Map<String, String>();
            this.queryParams = new Map<String, String>();
            this.timeoutMs = 10000; // default 10s (max 120000)
            this.compressed = true;
        }

        public CalloutConfig setMethod(String m) {
            if (String.isBlank(m)) throw new P2PCalloutException('Method cannot be blank');
            this.method = m.toUpperCase();
            return this;
        }
        public CalloutConfig setHeaders(Map<String, String> h) {
            if (h != null) this.headers.putAll(h);
            return this;
        }
        public CalloutConfig setHeader(String key, String value) {
            if (String.isBlank(key)) throw new P2PCalloutException('Header key cannot be blank');
            this.headers.put(key, value);
            return this;
        }
        public CalloutConfig setQueryParams(Map<String, String> q) {
            if (q != null) this.queryParams.putAll(q);
            return this;
        }
        public CalloutConfig setQueryParam(String key, String value) {
            this.queryParams.put(key, value);
            return this;
        }
        public CalloutConfig setBody(String b) {
            this.body = b;
            return this;
        }
        public CalloutConfig setBodyJson(Object obj) {
            this.body = JSON.serialize(obj);
            if (!this.headers.containsKey('Content-Type')) {
                this.headers.put('Content-Type', 'application/json');
            }
            return this;
        }
        public CalloutConfig setTimeout(Integer ms) {
            if (ms != null) this.timeoutMs = Math.min(Math.max(ms, 1), 120000);
            return this;
        }
        public CalloutConfig setCompressed(Boolean c) {
            this.compressed = c;
            return this;
        }
        public CalloutConfig setClientCert(String certDevName) {
            this.clientCertName = certDevName;
            return this;
        }

        // Build final endpoint with encoded query string
        public String getResolvedEndpoint() {
            if (queryParams.isEmpty()) return endpoint;
            List<String> parts = new List<String>();
            for (String k : queryParams.keySet()) {
                parts.add(
                    EncodingUtil.urlEncode(k, 'UTF-8') + '=' +
                    EncodingUtil.urlEncode(String.valueOf(queryParams.get(k)), 'UTF-8')
                );
            }
            String sep = endpoint.contains('?') ? '&' : '?';
            return endpoint + sep + String.join(parts, '&');
        }
    }

    // --- Core engine ---

    /**
     * Build HttpRequest from CalloutConfig without sending.
     * Useful for testing / inspecting.
     */
    public static HttpRequest buildRequest(CalloutConfig config) {
        if (config == null) throw new P2PCalloutException('CalloutConfig cannot be null');
        HttpRequest req = new HttpRequest();
        req.setEndpoint(config.getResolvedEndpoint());
        req.setMethod(config.method);
        req.setTimeout(config.timeoutMs);
        req.setCompressed(config.compressed);
        if (String.isNotBlank(config.clientCertName)) {
            req.setClientCertificateName(config.clientCertName);
        }
        for (String k : config.headers.keySet()) {
            req.setHeader(k, config.headers.get(k));
        }
        // Only set body for methods that support it and when body present
        if (String.isNotBlank(config.body) && config.method != 'GET' && config.method != 'HEAD') {
            req.setBody(config.body);
        }
        return req;
    }

    /**
     * Execute callout from config. Throws P2PCalloutException on failure.
     */
    public static HttpResponse send(CalloutConfig config) {
        HttpRequest req = buildRequest(config);
        try {
            Http http = new Http();
            HttpResponse res = http.send(req);
            return res;
        } catch (CalloutException e) {
            throw new P2PCalloutException('Callout failed to ' + config.getResolvedEndpoint() + ': ' + e.getMessage(), e);
        }
    }

    /**
     * Execute and assert 2xx. Throws if status code is not 2xx.
     */
    public static HttpResponse sendOrThrow(CalloutConfig config) {
        HttpResponse res = send(config);
        if (res.getStatusCode() < 200 || res.getStatusCode() >= 300) {
            throw new P2PCalloutException(
                'Non-success status ' + res.getStatusCode() + ' ' + res.getStatus() +
                ' from ' + config.getResolvedEndpoint() + ' Body: ' + res.getBody()
            );
        }
        return res;
    }

    // --- Convenience shortcuts ---

    public static HttpResponse get(String endpoint) {
        return send(new CalloutConfig(endpoint).setMethod('GET'));
    }
    public static HttpResponse get(String endpoint, Map<String, String> headers) {
        return send(new CalloutConfig(endpoint).setMethod('GET').setHeaders(headers));
    }
    public static HttpResponse get(String endpoint, Map<String, String> headers, Map<String, String> queryParams) {
        return send(new CalloutConfig(endpoint).setMethod('GET').setHeaders(headers).setQueryParams(queryParams));
    }

    public static HttpResponse post(String endpoint, String body, Map<String, String> headers) {
        return send(new CalloutConfig(endpoint).setMethod('POST').setBody(body).setHeaders(headers));
    }
    public static HttpResponse postJson(String endpoint, Object bodyObj, Map<String, String> headers) {
        return send(new CalloutConfig(endpoint).setMethod('POST').setBodyJson(bodyObj).setHeaders(headers));
    }

    public static HttpResponse put(String endpoint, String body, Map<String, String> headers) {
        return send(new CalloutConfig(endpoint).setMethod('PUT').setBody(body).setHeaders(headers));
    }
    public static HttpResponse putJson(String endpoint, Object bodyObj, Map<String, String> headers) {
        return send(new CalloutConfig(endpoint).setMethod('PUT').setBodyJson(bodyObj).setHeaders(headers));
    }

    public static HttpResponse patch(String endpoint, String body, Map<String, String> headers) {
        return send(new CalloutConfig(endpoint).setMethod('PATCH').setBody(body).setHeaders(headers));
    }
    public static HttpResponse patchJson(String endpoint, Object bodyObj, Map<String, String> headers) {
        return send(new CalloutConfig(endpoint).setMethod('PATCH').setBodyJson(bodyObj).setHeaders(headers));
    }

    public static HttpResponse del(String endpoint, Map<String, String> headers) {
        return send(new CalloutConfig(endpoint).setMethod('DELETE').setHeaders(headers));
    }

    // Generic JSON helper — deserialize response body
    public static Map<String, Object> sendAndParseJson(CalloutConfig config) {
        HttpResponse res = sendOrThrow(config);
        if (String.isBlank(res.getBody())) return new Map<String, Object>();
        return (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
    }

    // --- Named Credential helper (recommended for auth) ---
    // Pass endpoint like 'callout:MyNamedCred/some/path'
    public static HttpResponse sendViaNamedCredential(String namedCredentialPath, String method, String body, Map<String, String> headers) {
        String endpoint = namedCredentialPath.startsWith('callout:') ? namedCredentialPath : 'callout:' + namedCredentialPath;
        return send(new CalloutConfig(endpoint).setMethod(method).setBody(body).setHeaders(headers));
    }
}
