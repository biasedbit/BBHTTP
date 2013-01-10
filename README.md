BBHotpotato
===========

Hotpotato is a rich wrapper for **libcurl** written in Objective-C. Its name derives from the not-so-common misspelling of HTTP as HPTT.

It is an ARC-only library that uses [features](http://clang.llvm.org/docs/ObjectiveCLiterals.html) introduced by Clang 3.1. Thus, it is only suitable for iOS 5+ and OSX 10.7+.

If boasts an extremely simple and compact interface that allows you to reduce your code to fire off HTTP requests down to a couple of clean lines, while preserving full flexibility should you ever need it.

````objc
[[BBHTTPRequest getFrom:@"http://biasedbit.com"] execute:^(BBHTTPResponse* r) {
     NSLog(@"Finished: %u %@ -- received %u bytes of '%@'.",
           r.code, r.message, [r.data length], r[@"Content-Type"]);
 } error:^(NSError* e) {
     NSLog(@"Request failed: %@", [e localizedDescription]);
 }];

// Finished: 200 OK -- received 68364 bytes of 'text/html'.
````

There are still many features missing &mdash; automatic JSON parsing and multipart uploads to name a few &mdash; to bring it up-to-par with other similar projects. I want to add those over time but help is always more than welcome so be sure to open issues for the features you'd love to see or drop me a mention [@biasedbit](http://twitter.com/biasedbit) on Twitter.


## Highlights

* Super compact asynchronous-driven usage:

    ````objc
    [[BBHTTPRequest getFrom:@"http://biasedbit.com"] execute:^(BBHTTPResponse* response) {
        // handle response
    } error:nil]];
    ````

    > You don't even need to keep references to the requests, just fire and forget.

* Stream uploads from a `NSInputStream` or directly from a file:

    ````objc
    [[BBHTTPRequest postFile:@"/path/to/file" to:@"http://api.target.url/"]
     setup:^(BBHTTPRequest* request) {
         request[@"Extra-Header"] = @"something else";
     } andExecute:^(BBHTTPResponse* response) {
         // handle response
     } error:nil];
    ````

* Download to memory buffers or stream directly to file/`NSOutputStream`:

    ````objc
    [[BBHTTPRequest getFrom:@"http://biasedbit.com"]
     setup:^(BBHTTPRequest* request) {
         request.downloadToFile = @"/path/to/file";
     } andExecute:^(BBHTTPResponse* response) {
         // handle response
     } error:nil];
    ````

* Even the *power-dev* API is clean and concise:

    ````objc
    BBHTTPExecutor* twitterExecutor = [BBHTTPExecutor initWithId:@"twitter.com"];
    BBHTTPExecutor* facebookExecutor = [BBHTTPExecutor initWithId:@"facebook.com"];
    twitterExecutor.maxCurlHandles = 10;
    facebookExecutor.maxCurlHandles = 2;
    ...
    BBHTTPRequest* request = [[BBHTTPRequest alloc]
                              initWithURL:[NSURL URLWithString:@"http://twitter.com"]
                              andVerb:@"GET"];

    request[@"Accept-Language"] = @"en-us";
    request.downloadProgressBlock = ^(NSUInteger current, NSUInteger total) { /* ... */ };
    request.finishBlock = ^(BBHTTPResponse* response) { /* ... */ };

    [twitterExecutor executeRequest:request];
    ````


## Why?

You mean other than its super sexy API or the fact that it uses libcurl underneath?

Well, unlike `NSURLConnection` and, consequently, any lib that relies on it...

* is strictly compliant with [section 8.2.3](http://tools.ietf.org/html/rfc2616#section-8.2.3) of RFC 2616, a.k.a. the misbeloved `Expect: 100-Continue` header;
* can receive server error responses midway through upload &mdash; as opposed to continuing to pump data into socket eden, and eventually reporting connection timeout instead of the actual error response sent by the server.

*"But my uploads work just fine..."*

* If you only wrote code that uploads to a server, you've probably never noticed either of the above;
* If you wrote both client *and* server-side code to handle uploads, chances are that you never ran into either of the above;
* If you're hardcore and wrote your own server *and* client *and* noticed `NSURLConnection` ignores errors until it finishes its upload, then this is the HTTP framework for you. Also, fistbump for writing your server and client. And paying attention to the specs.

On a more serious tone, the motivation for this libcurl wrapper was that during development of [Droplr](http://droplr.com)'s API server, we noticed that whenever the API rejected an upload and immediately closed the connection &mdash; which is a perfectly legal & reasonable behavior &mdash; the Cocoa-based clients would keep reporting upload progress (even though I **knew** the socket was closed) and eventually fail with "Request timeout", instead of the response the server had sent down the pipes.

This meant that:

1. `NSURLConnection` wasn't waiting for the `100-Continue` provisional response before sending along the request body;
2. `NSURLConnection` wasn't realizing that a response was already sent and the connection was dying until it finished uploading what it had to upload. *stubborn bastard, eh?*

I did file a bug report but after a year of waiting for a response, I decided to come up with a working alternative. Coincidentally, the same day I let this library out in the open, I got a reply from Apple &mdash; closing the bug as a duplicate of some other I don't have access to.

A couple of quick tests with command line version of curl proved that curl knew how to properly handle these edge cases so it was time to build a new HTTP framework for Cocoa.

> During that process, [this handy build script](https://github.com/brunodecarvalho/curl-ios-build-scripts) was produced, so even if you don't want to use this library but are still interested in getting curl running on iOS, do check it out!


## Dependencies

* `libcurl`
* `CoreServices.framework` on OSX
* `MobileCoreServices.framework` on iOS
* `libz.dylib`

> **Note:**  
> Under `BBHotpotato/External/Curl` you can find libcurl, compiled against 6.0 SDK with support for i386 (simulator), armv7 and armv7s (iPhone 3GS and newer) but you can compile your own custom version with [this](https://github.com/brunodecarvalho/curl-ios-build-scripts).


## Documentation

The project includes comprehensive class-level documentation generated with [appledoc](https://github.com/tomaz/appledoc) under the `Docs` folder.

For guides on how to setup and start working with this lib, check out the Wiki pages.


## License

Hotpotato is licensed under the Apache Software License version 2.0
