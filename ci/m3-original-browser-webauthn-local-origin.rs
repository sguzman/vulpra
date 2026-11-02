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
            br#"<!doctype html><html><head><meta charset="utf-8"><title>Vulpra Offline WebAuthn QA</title></head>
<body><h1>Original browser offline WebAuthn</h1>
<button id="create" type="button">Register disposable virtual credential</button>
<button id="get" type="button">Assert disposable virtual credential</button>
<script>
"use strict";
window.__vulpraResult={create:null,get:null};
window.__vulpraM3Cred=null;
document.getElementById("create").addEventListener("click",function(){
 const options={
  challenge:new Uint8Array(32).fill(7),
  rp:{id:"localhost",name:"Private original-browser QA"},
  user:{id:new Uint8Array([1,2,3]),name:"disposable",displayName:"Disposable"},
  pubKeyCredParams:[{type:"public-key",alg:-7}],timeout:10000,
  authenticatorSelection:{authenticatorAttachment:"platform",userVerification:"discouraged"}
 };
 window.__vulpraResult.create={state:"started"};
 navigator.credentials.create({publicKey:options}).then(function(c){
  window.__vulpraM3Cred=new Uint8Array(c.rawId);
  window.__vulpraResult.create={state:"complete",ok:true,type:c.type,size:c.rawId.byteLength};
 }).catch(function(e){
  window.__vulpraResult.create={state:"complete",ok:false,error:e.name};
 });
});
document.getElementById("get").addEventListener("click",function(){
 const id=window.__vulpraM3Cred;
 if(!(id instanceof Uint8Array)){
  window.__vulpraResult.get={state:"complete",ok:false,error:"NoCreatedCredential"};return;
 }
 window.__vulpraResult.get={state:"started"};
 navigator.credentials.get({publicKey:{
  challenge:new Uint8Array(32).fill(13),rpId:"localhost",timeout:10000,
  allowCredentials:[{type:"public-key",id:id,transports:["internal"]}],
  userVerification:"discouraged"
 }}).then(function(c){
  window.__vulpraResult.get={state:"complete",ok:true,type:c.type,
   data:c.response.authenticatorData.byteLength,sig:c.response.signature.byteLength};
 }).catch(function(e){
  window.__vulpraResult.get={state:"complete",ok:false,error:e.name};
 });
});
</script></body></html>"#
        }else{b"Not found"};
        let header=if valid{"HTTP/1.1 200 OK"}else{"HTTP/1.1 404 Not Found"};
        let response=format!("{header}\r\nContent-Type: text/html; charset=utf-8\r\nCache-Control: no-store\r\nX-Content-Type-Options: nosniff\r\nContent-Length: {}\r\nConnection: close\r\n\r\n",body.len());
        let _=stream.write_all(response.as_bytes());
        let _=stream.write_all(body);
    }
}
