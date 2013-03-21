## 0.9.4

#### March 21st, 2013

* Ensure that the last `BBHTTPResponse` is always preserved as part of the `BBHTTPRequest`, even if the response content parser rejects the response.

    Previously only the error message (status code and status message) were being preserved, which led to `wasSuccessfullyExecuted` incorrectly reporting `NO`.


## 0.9.3

#### March 19th, 2013

* Added support to specify custom encoding when decoding response contents to NSString (#10)
* Add cancel handling block when using convenience executors
* Add missing interface declaration for `asImage` on convenience executors
* Renamed from BBHotpotato to BBHTTP