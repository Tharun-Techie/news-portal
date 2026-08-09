/**
 * P2PCalloutMock — reusable HttpCalloutMock for P2PCalloutService tests
 * Example:
 *   Test.setMock(HttpCalloutMock.class, new P2PCalloutMock(200, '{"ok":true}'));
 *   HttpResponse res = P2PCalloutService.get('https://example.com/api');
 */
@IsTest
global class P2PCalloutMock implements HttpCalloutMock {
    private Integer statusCode;
    private String body;
    private String status;
    private Map<String, String> headers;

    public P2PCalloutMock(Integer statusCode, String body) {
        this(statusCode, body, statusCode == 200 ? 'OK' : 'Error', new Map<String, String>{ 'Content-Type' => 'application/json' });
    }
    public P2PCalloutMock(Integer statusCode, String body, String status, Map<String, String> headers) {
        this.statusCode = statusCode;
        this.body = body;
        this.status = status;
        this.headers = headers != null ? headers : new Map<String, String>();
    }

    global HttpResponse respond(HttpRequest req) {
        HttpResponse res = new HttpResponse();
        res.setStatusCode(statusCode);
        res.setStatus(status);
        res.setBody(body);
        for (String k : headers.keySet()) {
            res.setHeader(k, headers.get(k));
        }
        return res;
    }

    // Route-based mock: map endpoint substring -> mock response
    public class RouteMock implements HttpCalloutMock {
        private Map<String, HttpResponse> routes;
        private HttpResponse defaultResponse;
        public RouteMock(Map<String, HttpResponse> routes, HttpResponse defaultResponse) {
            this.routes = routes;
            this.defaultResponse = defaultResponse;
        }
        global HttpResponse respond(HttpRequest req) {
            String ep = req.getEndpoint();
            for (String key : routes.keySet()) {
                if (ep.contains(key)) return routes.get(key);
            }
            return defaultResponse;
        }
        public static HttpResponse jsonRes(Integer code, String json) {
            HttpResponse r = new HttpResponse();
            r.setStatusCode(code);
            r.setStatus(code == 200 ? 'OK' : 'Error');
            r.setBody(json);
            r.setHeader('Content-Type', 'application/json');
            return r;
        }
    }
}
