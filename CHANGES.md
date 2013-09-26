## 0.9.9

#### September 26th, 2013

* Add form encoded POST
* Update to libcurl 7.32.0
* Update project file for Xcode 5

## 0.9.5

#### March 30th, 2013

* Add configurable upload and download speed limits (issue #3)
* Add configurable download timeout condition (issue #13)
* Change all init methods to return `instancetype` instead of `id`
* Remove unnecessary (and wrong) condition on upload and download transfer speeds query methods (`BBHTTPRequest`) that caused it to always report 0b/s until the request finished.


## 0.9.4

#### March 21st, 2013

* Ensure that the last `BBHTTPResponse` is always preserved as part of the `BBHTTPRequest`, even if the response content parser rejects the response.

    Previously only the error message (status code and status message) were being preserved, which led to `wasSuccessfullyExecuted` incorrectly reporting `NO`.


## 0.9.3

#### March 19th, 2013

* Added support to specify custom encoding when decoding response contents to NSString (issue #10)
* Add cancel handling block when using convenience executors
* Add missing interface declaration for `asImage` on convenience executors
* Renamed from BBHotpotato to BBHTTP
