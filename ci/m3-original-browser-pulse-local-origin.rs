// Minimal loopback-only WebAudio workload for an immutable original Vulpra binary.
// Native browser and PulseAudio session run in a disposable no-egress namespace.
use std::{env, io::{Read, Write}, net::TcpListener, time::Duration};
const HTML: &str = r#"<!doctype html><html><head><meta charset="utf-8"><title>Vulpra Pulse QA</title></head>
<body><button id="play" type="button">Start isolated audio</button>
<script>
"use strict";
window.__vulpraPulse={phase:"idle",ok:false};
document.getElementById("play").addEventListener("click",async function(){
 window.__vulpraPulse={phase:"starting",ok:false};
 try {
  const ctx=new AudioContext({sampleRate:48000});
  const osc=ctx.createOscillator();
  const gain=ctx.createGain();
  gain.gain.value=0.01;
  osc.frequency.value=220;
  osc.connect(gain);
  gain.connect(ctx.destination);
  osc.start();
  await ctx.resume();
  window.__vulpraPulse={phase:"running",ok:ctx.state==="running",
   state:ctx.state,sampleRate:ctx.sampleRate};
  setTimeout(async function(){osc.stop();await ctx.close();},8000);
 } catch(e) {
  window.__vulpraPulse={phase:"failed",ok:false,error:e.name};
 }
});
</script></body></html>"#;
fn main(){
    assert_eq!(env::args().nth(1).as_deref(),Some("vulpra-original-pulse-offline"));
    let listener=TcpListener::bind("127.0.0.1:18889").expect("loopback bind");
    for stream in listener.incoming() {
        let Ok(mut stream)=stream else {continue};
        let _=stream.set_read_timeout(Some(Duration::from_secs(3)));
        let mut request=[0u8;2048];
        let n=stream.read(&mut request).unwrap_or(0);
        if n==0 {continue;}
        let valid=request[..n].starts_with(b"GET / HTTP/1.1\r\n")
            ||request[..n].starts_with(b"GET / HTTP/1.0\r\n");
        let body=if valid {HTML} else {"Not found"};
        let response=format!("HTTP/1.1 {}\r\nContent-Type: text/html; charset=utf-8\r\nCache-Control: no-store\r\nX-Content-Type-Options: nosniff\r\nContent-Length: {}\r\nConnection: close\r\n\r\n",if valid {"200 OK"} else {"404 Not Found"},body.len());
        let _=stream.write_all(response.as_bytes());
        let _=stream.write_all(body.as_bytes());
    }
}
