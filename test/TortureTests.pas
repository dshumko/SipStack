unit TortureTests;

interface

const
  // Each constant is a message defined in
  // http://www.ietf.org/internet-drafts/draft-ietf-sipping-torture-tests-00.txt
  // TortureTextN is defined in section 2.N of the above.

  //   This message is a correctly formatted SIP message. It contains:
  //
  //   line folding all over
  //   escaped characters within quotes
  //   LWS between colons, semicolons, headers, and other fields
  //   both comma separated and separate listing of headers
  //   mix or short and long form for the same header
  //   unknown header field
  //   unusual header ordering
  //   unknown parameters of a known header
  //
  //   Proxies should forward message and clients should respond as to a
  //   normal INVITE message.
  TortureTest1 = 'INVITE sip:vivekg@chair.dnrc.bell-labs.com SIP/2.0'#13#10
               + 'TO :'#13#10
               + ' sip:vivekg@chair.dnrc.bell-labs.com ;   tag    = 1918181833n'#13#10
               + 'From   : "J Rosenberg \\\"" <sip:jdrosen@lucent.com>'#13#10
               + '  ;'#13#10
               + '  tag = 98asjd8'#13#10
               + 'Max-Forwards: 6'#13#10
               + 'Call-ID: 0ha0isndaksdj@10.1.1.1'#13#10
               + 'cseq: 8'#13#10
               + '  INVITE'#13#10
               + 'Via  : SIP  /   2.0'#13#10
               + ' /UDP'#13#10
               + '    135.180.130.133;branch=z9hG4bKkdjuw'#13#10
               + 'Subject :'#13#10
               + 'NewFangledHeader:   newfangled value'#13#10
               + ' more newfangled value'#13#10
               + 'Content-Type: application/sdp'#13#10
               + 'v:  SIP  / 2.0  / TCP     1192.168.156.222   ;'#13#10
               + '  branch  =   9ikj8  ,'#13#10
               + ' SIP  /    2.0   / UDP  192.168.255.111   ; hidden'#13#10
               + 'm:"Quoted string \"\"" <sip:jdrosen@bell-labs.com> ; newparam ='#13#10
               // http://www.ietf.org/internet-drafts/draft-ietf-sipping-torture-tests-00.txt
               // claims that this line starts with no space. That's illegal syntax though.
               // Therefore we use a TAB just to make things difficult for the parser.
               + #9'newvalue ;'#13#10
               + '  secondparam = secondvalue  ; q = 0.33,'#13#10
               + ' tel:4443322'#13#10
               + #13#10
               + 'v=0'#13#10
               + 'o=mhandley 29739 7272939 IN IP4 126.5.4.3'#13#10
               + 's=-'#13#10
               + 'c=IN IP4 135.180.130.88'#13#10
               + 't=0 0'#13#10
               + 'm=audio 492170 RTP/AVP 0 12'#13#10
               + 'm=video 3227 RTP/AVP 31'#13#10
               + 'a=rtpmap:31 LPC';

  //   This is a request with an unterminated quote in the display name of
  //   the To field.
  //
  //   The server can either return an error, or proxy it if it is
  //   successful parsing without the terminating quote.
  TortureTest19 = 'INVITE sip:user@company.com SIP/2.0'#13#10
                + 'To: "Mr. J. User <sip:j.user@company.com>'#13#10
                + 'From: sip:caller@university.edu;tag=93334'#13#10
                + 'Max-Forwards: 10'#13#10
                + 'Call-ID: 0ha0isndaksdj@10.0.0.1'#13#10
                + 'CSeq: 8 INVITE'#13#10
                + 'Via: SIP/2.0/UDP 135.180.130.133:5050;branch=z9hG4bKkdjuw'#13#10
                + 'Content-Type: application/sdp'#13#10
                + 'Content-Length: 138'#13#10
                + #13#10
                + 'v=0'#13#10
                + 'o=mhandley 29739 7272939 IN IP4 126.5.4.3'#13#10
                + 's=-'#13#10
                + 'c=IN IP4 135.180.130.88'#13#10
                + 't=0 0'#13#10
                + 'm=audio 492170 RTP/AVP 0 12'#13#10
                + 'm=video 3227 RTP/AVP 31'#13#10
                + 'a=rtpmap:31 LPC';

  //   This INVITE is illegal because the Request-URI has been enclosed
  //   within in "<>".
  //   An intelligent server may be able to deal with this and fix up
  //   athe Request-URI if acting as a Proxy. If not it should respond 400
  //   with an appropriate reason phrase.
  TortureTest21 = 'INVITE <sip:user@company.com> SIP/2.0'#13#10
                + 'To: sip:user@company.com'#13#10
                + 'From: sip:caller@university.edu;tag=39291'#13#10
                + 'Max-Forwards: 23'#13#10
                + 'Call-ID: 1@10.0.0.1'#13#10
                + 'CSeq: 1 INVITE'#13#10
                + 'Via: SIP/2.0/UDP 135.180.130.133'#13#10
                + 'Content-Type: application/sdp'#13#10
                + 'Content-Length: 174'#13#10
                + #13#10
                + 'v=0'#13#10
                + 'o=mhandley 29739 7272939 IN IP4 126.5.4.3'#13#10
                + 's=-'#13#10
                + 'c=IN IP4 135.180.130.88'#13#10
                + 't=3149328700 0'#13#10
                + 'm=audio 492170 RTP/AVP 0 12'#13#10
                + 'm=video 3227 RTP/AVP 31'#13#10
                + 'a=rtpmap:31 LPC';

  //   This INVITE has illegal LWS within the SIP URI.
  //
  //   An intelligent server may be able to deal with this and fix up
  //   the Request-URI if acting as a Proxy. If not it should respond 400
  //   with an appropriate reason phrase.
  TortureTest22 = 'INVITE sip:user@company.com; transport=udp SIP/2.0'#13#10
                + 'To: sip:user@company.com'#13#10
                + 'From: sip:caller@university.edu;tag=231413434'#13#10
                + 'Max-Forwards: 5'#13#10
                + 'Call-ID: 2@10.0.0.1'#13#10
                + 'CSeq: 1 INVITE'#13#10
                + 'Via: SIP/2.0/UDP 135.180.130.133:5060;branch=z9hG4bKkdjuw'#13#10
                + 'Content-Type: application/sdp'#13#10
                + 'Content-Length: 174'#13#10
                + #13#10
                + 'v=0'#13#10
                + 'o=mhandley 29739 7272939 IN IP4 126.5.4.3'#13#10
                + 's=-'#13#10
                + 'c=IN IP4 135.180.130.88'#13#10
                + 't=3149328700 0'#13#10
                + 'm=audio 492170 RTP/AVP 0 12'#13#10
                + 'm=video 3227 RTP/AVP 31'#13#10
                + 'a=rtpmap:31 LPC';

  //   This INVITE has illegal >1 SP between elements of the Request-URI.
  //
  //   An intelligent server may be able to deal with this and fix up
  //   the Request-URI if acting as a Proxy. If not it should respond 400
  //   with an appropriate reason phrase.
  TortureTest23 = 'INVITE sip:user@company.com  SIP/2.0'#13#10
                + 'Max-Forwards: 8'#13#10
                + 'To: sip:user@company.com'#13#10
                + 'From: sip:caller@university.edu;tag=8814'#13#10
                + 'Call-ID: 3@10.0.0.1'#13#10
                + 'CSeq: 1 INVITE'#13#10
                + 'Via: SIP/2.0/UDP 135.180.130.133:5060;branch=z9hG4bKkdjuw'#13#10
                + 'Content-Type: application/sdp'#13#10
                + 'Content-Length: 174'#13#10
                + #13#10
                + 'v=0'#13#10
                + 'o=mhandley 29739 7272939 IN IP4 126.5.4.3'#13#10
                + 's=-'#13#10
                + 'c=IN IP4 135.180.130.88'#13#10
                + 't=0 0'#13#10
                + 'm=audio 492170 RTP/AVP 0 12'#13#10
                + 'm=video 3227 RTP/AVP 31'#13#10
                + 'a=rtpmap:31 LPC';

  //   This OPTIONS request is legal despite there being no LWS between
  //   the display name and < in the From header.
  TortureTest27 = 'OPTIONS sip:user@company.com SIP/2.0'#13#10
                + 'To: sip:user@company.com'#13#10
                + 'From: "caller"<sip:caller@example.com>;tag=323'#13#10
                + 'Max-Forwards: 70'#13#10
                + 'Call-ID: 1234abcd@10.0.0.1'#13#10
                + 'CSeq: 1 OPTIONS'#13#10
                + 'Via: SIP/2.0/UDP 135.180.130.133:5060;branch=z9hG4bKkdjuw';

  //   This is an illegal and badly mangled message.
  //
  //   A server should respond 400 with an appropriate reason phrase if it
  //   can. It may just drop this message.
  TortureTest35 = 'OPTIONS sip:135.180.130.133 SIP/2.0'#13#10
                + 'Via: SIP/2.0/UDP company.com:5604'#13#10
                + 'Max-Forwards: 70'#13#10
                + 'From: sip:iuser@company.com;tag=74345345'#13#10
                + 'To: sip:user@135.180.130.133'#13#10
                + 'Call-ID: 1804928587@company.com'#13#10
                + 'CSeq: 1 OPTIONS'#13#10
                + 'Expires: 0 0l@company.com'#13#10
                + 'To: sip:user@135.180.130.133'#13#10
                + 'Call-ID: 1804928587@company.com'#13#10
                + 'CSeq: 1 OPTIONS'#13#10
                + 'Contact: sip:host.company.com'#13#10
                + 'Expires: 0xpires: 0sip:host.company.com'#13#10
                + 'Expires: 0'#13#10
                + 'Contact: sip:host.company.com';

  //   This is an illegal invite at the display names in the To and From
  //   headers contain non-token characters but are unquoted.
  //
  //   A server may be intelligent enough to cope with this but may also
  //   return a 400 response with an appropriate reason phrase.

  TortureTest40 = 'INVITE sip:t.watson@ieee.org SIP/2.0'#13#10
                + 'Via:     SIP/2.0/UDP c.bell-tel.com:5060;branch=z9hG4bKkdjuw'#13#10
                + 'Max-Forwards:      70'#13#10
                + 'From:    Bell, Alexander <sip:a.g.bell@bell-tel.com>;tag=43'#13#10
                + 'To:      Watson, Thomas <sip:t.watson@ieee.org>'#13#10
                + 'Call-ID: 31415@c.bell-tel.com'#13#10
                + 'CSeq:    1 INVITE';

implementation

end.
