// Minimal fixed-origin HTTP server for isolated original browser WebAuthn QA.
// Static content only; loopback-only; no network outside the namespace.
use std::{env,io::{Read,Write},net::TcpListener,time::Duration};
fn main(){
    let listener=TcpListener::bind("127.0.0.1:18888").expect("loopback bind");
    let limit=env::args().nth(1).unwrap_or_default();
    assert_eq!(limit,"vulpra-original-offline-webauthn");
    for conn in listener.incoming(){
        let Ok(mut stream)=conn else {continue};
        let _=stream.set_read_timeout(Some(Duration::from_secs(3)));
        let mut request=[0u8;4096];
        let n=stream.read(&mut request).unwrap_or(0);
        if n==0 {continue;}
        let valid=request[..n].starts_with(b"GET / HTTP/1.1\r\n")
            || request[..n].starts_with(b"GET / HTTP/1.0\r\n");
        let body: &[u8]=if valid{
            b"<!doctype html><meta charset=utf-8><title>Vulpra Offline WebAuthn QA</title><main>Original browser, offline, disposable credentials only.</main>"
        }else{b"Not found"};
        let header=if valid{"HTTP/1.1 200 OK"}else{"HTTP/1.1 404 Not Found"};
        let response=format!("{header}\r\nContent-Type: text/html; charset=utf-8\r\nCache-Control: no-store\r\nX-Content-Type-Options: nosniff\r\nContent-Length: {}\r\nConnection: close\r\n\r\n",body.len());
        let _=stream.write_all(response.as_bytes());
        let _=stream.write_all(body);
    }
}
