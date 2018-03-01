# Copyright 2016 Google Inc. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require_relative '../helper'
require 'fluent/plugin/exception_detector'

class ExceptionDetectorTest < Test::Unit::TestCase
  JAVA_EXC_PART1 = <<END.freeze
Jul 09, 2015 3:23:29 PM com.google.devtools.search.cloud.feeder.MakeLog: RuntimeException: Run from this message!
  at com.my.app.Object.do$a1(MakeLog.java:50)
  at java.lang.Thing.call(Thing.java:10)
END

  JAVA_EXC_PART2 = <<END.freeze
  at com.my.app.Object.help(MakeLog.java:40)
  at sun.javax.API.method(API.java:100)
  at com.jetty.Framework.main(MakeLog.java:30)
END

  JAVA_EXC = (JAVA_EXC_PART1 + JAVA_EXC_PART2).freeze

  COMPLEX_JAVA_EXC = <<END.freeze
javax.servlet.ServletException: Something bad happened
    at com.example.myproject.OpenSessionInViewFilter.doFilter(OpenSessionInViewFilter.java:60)
    at org.mortbay.jetty.servlet.ServletHandler$CachedChain.doFilter(ServletHandler.java:1157)
    at com.example.myproject.ExceptionHandlerFilter.doFilter(ExceptionHandlerFilter.java:28)
    at org.mortbay.jetty.servlet.ServletHandler$CachedChain.doFilter(ServletHandler.java:1157)
    at com.example.myproject.OutputBufferFilter.doFilter(OutputBufferFilter.java:33)
    at org.mortbay.jetty.servlet.ServletHandler$CachedChain.doFilter(ServletHandler.java:1157)
    at org.mortbay.jetty.servlet.ServletHandler.handle(ServletHandler.java:388)
    at org.mortbay.jetty.security.SecurityHandler.handle(SecurityHandler.java:216)
    at org.mortbay.jetty.servlet.SessionHandler.handle(SessionHandler.java:182)
    at org.mortbay.jetty.handler.ContextHandler.handle(ContextHandler.java:765)
    at org.mortbay.jetty.webapp.WebAppContext.handle(WebAppContext.java:418)
    at org.mortbay.jetty.handler.HandlerWrapper.handle(HandlerWrapper.java:152)
    at org.mortbay.jetty.Server.handle(Server.java:326)
    at org.mortbay.jetty.HttpConnection.handleRequest(HttpConnection.java:542)
    at org.mortbay.jetty.HttpConnection$RequestHandler.content(HttpConnection.java:943)
    at org.mortbay.jetty.HttpParser.parseNext(HttpParser.java:756)
    at org.mortbay.jetty.HttpParser.parseAvailable(HttpParser.java:218)
    at org.mortbay.jetty.HttpConnection.handle(HttpConnection.java:404)
    at org.mortbay.jetty.bio.SocketConnector$Connection.run(SocketConnector.java:228)
    at org.mortbay.thread.QueuedThreadPool$PoolThread.run(QueuedThreadPool.java:582)
Caused by: com.example.myproject.MyProjectServletException
    at com.example.myproject.MyServlet.doPost(MyServlet.java:169)
    at javax.servlet.http.HttpServlet.service(HttpServlet.java:727)
    at javax.servlet.http.HttpServlet.service(HttpServlet.java:820)
    at org.mortbay.jetty.servlet.ServletHolder.handle(ServletHolder.java:511)
    at org.mortbay.jetty.servlet.ServletHandler$CachedChain.doFilter(ServletHandler.java:1166)
    at com.example.myproject.OpenSessionInViewFilter.doFilter(OpenSessionInViewFilter.java:30)
    ... 27 more
END

  NODE_JS_EXC = <<END.freeze
ReferenceError: myArray is not defined
  at next (/app/node_modules/express/lib/router/index.js:256:14)
  at /app/node_modules/express/lib/router/index.js:615:15
  at next (/app/node_modules/express/lib/router/index.js:271:10)
  at Function.process_params (/app/node_modules/express/lib/router/index.js:330:12)
  at /app/node_modules/express/lib/router/index.js:277:22
  at Layer.handle [as handle_request] (/app/node_modules/express/lib/router/layer.js:95:5)
  at Route.dispatch (/app/node_modules/express/lib/router/route.js:112:3)
  at next (/app/node_modules/express/lib/router/route.js:131:13)
  at Layer.handle [as handle_request] (/app/node_modules/express/lib/router/layer.js:95:5)
  at /app/app.js:52:3
END

  CLIENT_JS_EXC = <<END.freeze
Error
    at bls (<anonymous>:3:9)
    at <anonymous>:6:4
    at a_function_name
    at Object.InjectedScript._evaluateOn (http://<anonymous>/file.js?foo=bar:875:140)
    at Object.InjectedScript.evaluate (<anonymous>)
END

  V8_JS_EXC = <<END.freeze
V8 errors stack trace
  eval at Foo.a (eval at Bar.z (myscript.js:10:3))
  at new Contructor.Name (native)
  at new FunctionName (unknown location)
  at Type.functionName [as methodName] (file(copy).js?query='yes':12:9)
  at functionName [as methodName] (native)
  at Type.main(sample(copy).js:6:4)
END

  PYTHON_EXC = <<END.freeze
Traceback (most recent call last):
  File "/base/data/home/runtimes/python27/python27_lib/versions/third_party/webapp2-2.5.2/webapp2.py", line 1535, in __call__
    rv = self.handle_exception(request, response, e)
  File "/base/data/home/apps/s~nearfieldspy/1.378705245900539993/nearfieldspy.py", line 17, in start
    return get()
  File "/base/data/home/apps/s~nearfieldspy/1.378705245900539993/nearfieldspy.py", line 5, in get
    raise Exception('spam', 'eggs')
Exception: ('spam', 'eggs')
END

  PHP_EXC = <<END.freeze
exception 'Exception' with message 'Custom exception' in /home/joe/work/test-php/test.php:5
Stack trace:
#0 /home/joe/work/test-php/test.php(9): func1()
#1 /home/joe/work/test-php/test.php(13): func2()
#2 {main}
END

  PHP_ON_GAE_EXC = <<END.freeze
PHP Fatal error:  Uncaught exception 'Exception' with message 'message' in /base/data/home/apps/s~crash-example-php/1.388306779641080894/errors.php:60
Stack trace:
#0 [internal function]: ErrorEntryGenerator::{closure}()
#1 /base/data/home/apps/s~crash-example-php/1.388306779641080894/errors.php(20): call_user_func_array(Object(Closure), Array)
#2 /base/data/home/apps/s~crash-example-php/1.388306779641080894/index.php(36): ErrorEntry->__call('raise', Array)
#3 /base/data/home/apps/s~crash-example-php/1.388306779641080894/index.php(36): ErrorEntry->raise()
#4 {main}
  thrown in /base/data/home/apps/s~crash-example-php/1.388306779641080894/errors.php on line 60
END

  GO_EXC = <<END.freeze
panic: my panic

goroutine 4 [running]:
panic(0x45cb40, 0x47ad70)
	/usr/local/go/src/runtime/panic.go:542 +0x46c fp=0xc42003f7b8 sp=0xc42003f710 pc=0x422f7c
main.main.func1(0xc420024120)
	foo.go:6 +0x39 fp=0xc42003f7d8 sp=0xc42003f7b8 pc=0x451339
runtime.goexit()
	/usr/local/go/src/runtime/asm_amd64.s:2337 +0x1 fp=0xc42003f7e0 sp=0xc42003f7d8 pc=0x44b4d1
created by main.main
	foo.go:5 +0x58

goroutine 1 [chan receive]:
runtime.gopark(0x4739b8, 0xc420024178, 0x46fcd7, 0xc, 0xc420028e17, 0x3)
	/usr/local/go/src/runtime/proc.go:280 +0x12c fp=0xc420053e30 sp=0xc420053e00 pc=0x42503c
runtime.goparkunlock(0xc420024178, 0x46fcd7, 0xc, 0x1000f010040c217, 0x3)
	/usr/local/go/src/runtime/proc.go:286 +0x5e fp=0xc420053e70 sp=0xc420053e30 pc=0x42512e
runtime.chanrecv(0xc420024120, 0x0, 0xc420053f01, 0x4512d8)
	/usr/local/go/src/runtime/chan.go:506 +0x304 fp=0xc420053f20 sp=0xc420053e70 pc=0x4046b4
runtime.chanrecv1(0xc420024120, 0x0)
	/usr/local/go/src/runtime/chan.go:388 +0x2b fp=0xc420053f50 sp=0xc420053f20 pc=0x40439b
main.main()
	foo.go:9 +0x6f fp=0xc420053f80 sp=0xc420053f50 pc=0x4512ef
runtime.main()
	/usr/local/go/src/runtime/proc.go:185 +0x20d fp=0xc420053fe0 sp=0xc420053f80 pc=0x424bad
runtime.goexit()
	/usr/local/go/src/runtime/asm_amd64.s:2337 +0x1 fp=0xc420053fe8 sp=0xc420053fe0 pc=0x44b4d1

goroutine 2 [force gc (idle)]:
runtime.gopark(0x4739b8, 0x4ad720, 0x47001e, 0xf, 0x14, 0x1)
	/usr/local/go/src/runtime/proc.go:280 +0x12c fp=0xc42003e768 sp=0xc42003e738 pc=0x42503c
runtime.goparkunlock(0x4ad720, 0x47001e, 0xf, 0xc420000114, 0x1)
	/usr/local/go/src/runtime/proc.go:286 +0x5e fp=0xc42003e7a8 sp=0xc42003e768 pc=0x42512e
runtime.forcegchelper()
	/usr/local/go/src/runtime/proc.go:238 +0xcc fp=0xc42003e7e0 sp=0xc42003e7a8 pc=0x424e5c
runtime.goexit()
	/usr/local/go/src/runtime/asm_amd64.s:2337 +0x1 fp=0xc42003e7e8 sp=0xc42003e7e0 pc=0x44b4d1
created by runtime.init.4
	/usr/local/go/src/runtime/proc.go:227 +0x35

goroutine 3 [GC sweep wait]:
runtime.gopark(0x4739b8, 0x4ad7e0, 0x46fdd2, 0xd, 0x419914, 0x1)
	/usr/local/go/src/runtime/proc.go:280 +0x12c fp=0xc42003ef60 sp=0xc42003ef30 pc=0x42503c
runtime.goparkunlock(0x4ad7e0, 0x46fdd2, 0xd, 0x14, 0x1)
	/usr/local/go/src/runtime/proc.go:286 +0x5e fp=0xc42003efa0 sp=0xc42003ef60 pc=0x42512e
runtime.bgsweep(0xc42001e150)
	/usr/local/go/src/runtime/mgcsweep.go:52 +0xa3 fp=0xc42003efd8 sp=0xc42003efa0 pc=0x419973
runtime.goexit()
	/usr/local/go/src/runtime/asm_amd64.s:2337 +0x1 fp=0xc42003efe0 sp=0xc42003efd8 pc=0x44b4d1
created by runtime.gcenable
	/usr/local/go/src/runtime/mgc.go:216 +0x58
END

  GO_ON_GAE_EXC = <<END.freeze
panic: runtime error: index out of range

goroutine 12 [running]:
main88989.memoryAccessException()
	crash_example_go.go:58 +0x12a
main88989.handler(0x2afb7042a408, 0xc01042f880, 0xc0104d3450)
	crash_example_go.go:36 +0x7ec
net/http.HandlerFunc.ServeHTTP(0x13e5128, 0x2afb7042a408, 0xc01042f880, 0xc0104d3450)
	go/src/net/http/server.go:1265 +0x56
net/http.(*ServeMux).ServeHTTP(0xc01045cab0, 0x2afb7042a408, 0xc01042f880, 0xc0104d3450)
	go/src/net/http/server.go:1541 +0x1b4
appengine_internal.executeRequestSafely(0xc01042f880, 0xc0104d3450)
	go/src/appengine_internal/api_prod.go:288 +0xb7
appengine_internal.(*server).HandleRequest(0x15819b0, 0xc010401560, 0xc0104c8180, 0xc010431380, 0x0, 0x0)
	go/src/appengine_internal/api_prod.go:222 +0x102b
reflect.Value.call(0x1243fe0, 0x15819b0, 0x113, 0x12c8a20, 0x4, 0xc010485f78, 0x3, 0x3, 0x0, 0x0, ...)
	/tmp/appengine/go/src/reflect/value.go:419 +0x10fd
reflect.Value.Call(0x1243fe0, 0x15819b0, 0x113, 0xc010485f78, 0x3, 0x3, 0x0, 0x0, 0x0)
	/tmp/ap
END

  GO_SIGNAL_EXC = <<END.freeze
panic: runtime error: invalid memory address or nil pointer dereference
[signal SIGSEGV: segmentation violation code=0x1 addr=0x0 pc=0x7fd34f]

goroutine 5 [running]:
panics.nilPtrDereference()
	panics/panics.go:33 +0x1f
panics.Wait()
	panics/panics.go:16 +0x3b
created by main.main
	server.go:20 +0x91
END

  CSHARP_EXC = <<END.freeze
System.Collections.Generic.KeyNotFoundException: The given key was not present in the dictionary.
  at System.Collections.Generic.Dictionary`2[System.String,System.Collections.Generic.Dictionary`2[System.Int32,System.Double]].get_Item (System.String key) [0x00000] in <filename unknown>:0
  at File3.Consolidator_Class.Function5 (System.Collections.Generic.Dictionary`2 names, System.Text.StringBuilder param_4) [0x00007] in /usr/local/google/home/Csharp/another file.csharp:9
  at File3.Consolidator_Class.Function4 (System.Text.StringBuilder param_4, System.Double[,,] array) [0x00013] in /usr/local/google/home/Csharp/another file.csharp:23
  at File3.Consolidator_Class.Function3 (Int32 param_3) [0x0000f] in /usr/local/google/home/Csharp/another file.csharp:27
  at File3.Consolidator_Class.Function3 (System.Text.StringBuilder param_3) [0x00007] in /usr/local/google/home/Csharp/another file.csharp:32
  at File2.Processor.Function2 (System.Int32& param_2, System.Collections.Generic.Stack`1& numbers) [0x00003] in /usr/local/google/home/Csharp/File2.csharp:19
  at File2.Processor.Random2 () [0x00037] in /usr/local/google/home/Csharp/File2.csharp:28
  at File2.Processor.Function1 (Int32 param_1, System.Collections.Generic.Dictionary`2 map) [0x00007] in /usr/local/google/home/Csharp/File2.csharp:34
  at Main.Welcome+<Main>c__AnonStorey0.<>m__0 () [0x00006] in /usr/local/google/home/Csharp/hello.csharp:48
  at System.Threading.Thread.StartInternal () [0x00000] in <filename unknown>:0
END

  RUBY_EXC = <<END.freeze
 NoMethodError (undefined method `resursivewordload' for #<BooksController:0x007f8dd9a0c738>):
  app/controllers/books_controller.rb:69:in `recursivewordload'
  app/controllers/books_controller.rb:75:in `loadword'
  app/controllers/books_controller.rb:79:in `loadline'
  app/controllers/books_controller.rb:83:in `loadparagraph'
  app/controllers/books_controller.rb:87:in `loadpage'
  app/controllers/books_controller.rb:91:in `onload'
  app/controllers/books_controller.rb:95:in `loadrecursive'
  app/controllers/books_controller.rb:99:in `requestload'
  app/controllers/books_controller.rb:118:in `generror'
  config/error_reporting_logger.rb:62:in `tagged'
END

  # The whitespace on the second line is significant.
  # rubocop:disable TrailingWhitespace
  RAILS_EXC = <<END.freeze
 ActionController::RoutingError (No route matches [GET] "/settings"):
  
  actionpack (5.1.4) lib/action_dispatch/middleware/debug_exceptions.rb:63:in `call'
  actionpack (5.1.4) lib/action_dispatch/middleware/show_exceptions.rb:31:in `call'
  railties (5.1.4) lib/rails/rack/logger.rb:36:in `call_app'
  railties (5.1.4) lib/rails/rack/logger.rb:24:in `block in call'
  activesupport (5.1.4) lib/active_support/tagged_logging.rb:69:in `block in tagged'
  activesupport (5.1.4) lib/active_support/tagged_logging.rb:26:in `tagged'
  activesupport (5.1.4) lib/active_support/tagged_logging.rb:69:in `tagged'
  railties (5.1.4) lib/rails/rack/logger.rb:24:in `call'
  actionpack (5.1.4) lib/action_dispatch/middleware/remote_ip.rb:79:in `call'
  actionpack (5.1.4) lib/action_dispatch/middleware/request_id.rb:25:in `call'
  rack (2.0.3) lib/rack/method_override.rb:22:in `call'
  rack (2.0.3) lib/rack/runtime.rb:22:in `call'
  activesupport (5.1.4) lib/active_support/cache/strategy/local_cache_middleware.rb:27:in `call'
  actionpack (5.1.4) lib/action_dispatch/middleware/executor.rb:12:in `call'
  rack (2.0.3) lib/rack/sendfile.rb:111:in `call'
  railties (5.1.4) lib/rails/engine.rb:522:in `call'
  puma (3.10.0) lib/puma/configuration.rb:225:in `call'
  puma (3.10.0) lib/puma/server.rb:605:in `handle_request'
  puma (3.10.0) lib/puma/server.rb:437:in `process_client'
  puma (3.10.0) lib/puma/server.rb:301:in `block in run'
  puma (3.10.0) lib/puma/thread_pool.rb:120:in `block in spawn_thread'
END

  DART_EXC = <<END.freeze
Unhandled exception:
some uncaught exception
#0      handleFailure (file:///test/example/http/handling_an_httprequest_error.dart:16:3)
#1      main (file:///test/example/http/handling_an_httprequest_error.dart:24:5)
<asynchronous suspension>
#2      _startIsolate.<anonymous closure> (dart:isolate-patch/isolate_patch.dart:265)
#3      _RawReceivePortImpl._handleMessage (dart:isolate-patch/isolate_patch.dart:151)
END

  DART_COMPLEX_EXC = <<END.freeze
Unhandled exception:
'file:///test/express/test/server.dart': malformed type: line 31 pos 7: cannot resolve class 'TestClass' from '::'
  new TestClass();
      ^


#0      _TypeError._throwNew (dart:core-patch/errors_patch.dart:82)
#1      one (file:///test/express/test/server.dart:31:7)
<asynchronous suspension>
#2      main.<anonymous closure> (file:///test/express/test/server.dart:15:7)
#3      _Route.managedRequestHandler.<anonymous closure> (package:express/_route.dart:34:23)
#4      _Route.handle (package:express/_route.dart:27:23)
#5      _Express.listen.<anonymous closure>.<anonymous closure>.<anonymous closure> (package:express/_express.dart:165:27)
#6      _RootZone.runGuarded (dart:async/zone.dart:1296)
#7      _BufferingStreamSubscription._sendDone.sendDone (dart:async/stream_impl.dart:384)
#8      _BufferingStreamSubscription._sendDone (dart:async/stream_impl.dart:394)
#9      _BufferingStreamSubscription._close (dart:async/stream_impl.dart:277)
#10     _ForwardingStream._handleDone (dart:async/stream_pipe.dart:106)
#11     _ForwardingStreamSubscription._handleDone (dart:async/stream_pipe.dart:172)
#12     _RootZone.runGuarded (dart:async/zone.dart:1296)
#13     _BufferingStreamSubscription._sendDone.sendDone (dart:async/stream_impl.dart:384)
#14     _BufferingStreamSubscription._sendDone (dart:async/stream_impl.dart:394)
#15     _DelayedDone.perform (dart:async/stream_impl.dart:598)
#16     _StreamImplEvents.handleNext (dart:async/stream_impl.dart:695)
#17     _PendingEvents.schedule.<anonymous closure> (dart:async/stream_impl.dart:655)
#18     _microtaskLoop (dart:async/schedule_microtask.dart:41)
#19     _startMicrotaskLoop (dart:async/schedule_microtask.dart:50)
#20     _runPendingImmediateCallback (dart:isolate-patch/isolate_patch.dart:99)
#21     _RawReceivePortImpl._handleMessage (dart:isolate-patch/isolate_patch.dart:152)
END

  ARBITRARY_TEXT = <<END.freeze
This arbitrary text.
It sounds tympanic: a word which means like a drum.

I am glad it contains no exception.
END

  def check_multiline(detector, expected_first, expected_last, multiline)
    lines = multiline.lines
    lines.each_with_index do |line, index|
      action = detector.update(line)
      case index
      when 0
        assert_equal(expected_first, action,
                     "unexpected action on first line: #{line}")
      when lines.length - 1
        assert_equal(expected_last, action,
                     "unexpected action on last line: #{line}")
      else
        assert_equal(:inside_trace, action, "line not buffered: #{line}")
      end
    end
  end

  def check_no_multiline(detector, text)
    text.lines.each do |line|
      action = detector.update(line)
      assert_equal(:no_trace, action, "unexpected action on line: #{line}")
    end
  end

  def check_exception(exception, detects_end)
    detector = Fluent::ExceptionDetector.new
    after_exc = detects_end ? :end_trace : :inside_trace
    before_second_exc = detects_end ? :inside_trace : :start_trace
    check_multiline(detector, :no_trace, :no_trace, 'This is not an exception.')
    check_multiline(detector, :inside_trace, after_exc, exception)
    check_multiline(detector, :no_trace, :no_trace, 'This is not an exception.')
    check_multiline(detector, :inside_trace, after_exc, exception)
    check_multiline(detector, before_second_exc, after_exc, exception)
  end

  def test_java
    check_exception(JAVA_EXC, false)
    check_exception(COMPLEX_JAVA_EXC, false)
  end

  def test_js
    check_exception(NODE_JS_EXC, false)
    check_exception(CLIENT_JS_EXC, false)
    check_exception(V8_JS_EXC, false)
  end

  def test_csharp
    check_exception(CSHARP_EXC, false)
  end

  def test_python
    check_exception(PYTHON_EXC, true)
  end

  def test_php
    check_exception(PHP_EXC, false)
    check_exception(PHP_ON_GAE_EXC, true)
  end

  def test_go
    check_exception(GO_EXC, false)
    check_exception(GO_ON_GAE_EXC, false)
    check_exception(GO_SIGNAL_EXC, false)
  end

  def test_ruby
    check_exception(RUBY_EXC, false)
    check_exception(RAILS_EXC, false)
  end

  def test_dart
    check_exception(DART_EXC, false)
    check_exception(DART_COMPLEX_EXC, false)
  end

  def test_mixed_languages
    check_exception(JAVA_EXC, false)
    check_exception(PYTHON_EXC, true)
    check_exception(COMPLEX_JAVA_EXC, false)
    check_exception(NODE_JS_EXC, false)
    check_exception(PHP_EXC, false)
    check_exception(PHP_ON_GAE_EXC, true)
    check_exception(CLIENT_JS_EXC, false)
    check_exception(GO_EXC, false)
    check_exception(GO_ON_GAE_EXC, false)
    check_exception(GO_SIGNAL_EXC, false)
    check_exception(CSHARP_EXC, false)
    check_exception(V8_JS_EXC, false)
    check_exception(RUBY_EXC, false)
    check_exception(DART_EXC, false)
    check_exception(DART_COMPLEX_EXC, false)
  end

  def test_reset
    detector = Fluent::ExceptionDetector.new

    check_multiline(detector, :inside_trace, :inside_trace, JAVA_EXC_PART1)
    check_multiline(detector, :inside_trace, :inside_trace, JAVA_EXC_PART2)

    check_multiline(detector, :start_trace, :inside_trace, JAVA_EXC_PART1)
    detector.reset
    check_no_multiline(detector, JAVA_EXC_PART2)
  end

  def feed_lines(buffer, *messages)
    messages.each do |m|
      m.each_line do |line|
        buffer.push(0, line)
      end
      buffer.flush
    end
  end

  Struct.new('TestBufferScenario', :desc, :languages, :input, :expected)

  def buffer_scenario(desc, languages, input, expected)
    Struct::TestBufferScenario.new(desc, languages, input, expected)
  end

  def test_buffer
    [
      buffer_scenario('mixed languages',
                      [:all],
                      [JAVA_EXC, ARBITRARY_TEXT, PYTHON_EXC, GO_EXC],
                      [JAVA_EXC] + ARBITRARY_TEXT.lines + [PYTHON_EXC, GO_EXC]),
      buffer_scenario('single language',
                      [:go],
                      [JAVA_EXC, ARBITRARY_TEXT, GO_EXC],
                      JAVA_EXC.lines + ARBITRARY_TEXT.lines + [GO_EXC]),
      buffer_scenario('some exceptions from non-configured languages',
                      [:python],
                      [JAVA_EXC, PYTHON_EXC, GO_EXC],
                      JAVA_EXC.lines + [PYTHON_EXC] + GO_EXC.lines),
      buffer_scenario('all exceptions from non-configured languages',
                      [:ruby],
                      [JAVA_EXC, PYTHON_EXC, GO_EXC],
                      JAVA_EXC.lines + PYTHON_EXC.lines + GO_EXC.lines)
    ].each do |s|
      out = []
      buffer = Fluent::TraceAccumulator.new(nil,
                                            s.languages) { |_, m| out << m }
      feed_lines(buffer, *s.input)
      assert_equal(s.expected, out, s.desc)
    end
  end

  def feed_json(buffer, message_field, messages)
    messages.each do |m|
      m.each_line do |line|
        buffer.push(0, message_field => line)
      end
      buffer.flush
    end
  end

  def expected_json(message_field, messages)
    messages.collect { |m| { message_field => [m].flatten.join } }
  end

  Struct.new('TestJsonScenario',
             :desc, :configured_field, :actual_field, :input, :output)

  def json_scenario(desc, configured_field, actual_field, input, output)
    Struct::TestJsonScenario.new(desc, configured_field, actual_field,
                                 input, output)
  end

  def test_json_messages
    [
      json_scenario('User-defined message field', 'mydata', 'mydata',
                    [PYTHON_EXC, ARBITRARY_TEXT, GO_EXC],
                    [PYTHON_EXC] + ARBITRARY_TEXT.lines + [GO_EXC]),
      json_scenario('Default message field "message"', '', 'message',
                    [PYTHON_EXC, ARBITRARY_TEXT, GO_EXC],
                    [PYTHON_EXC] + ARBITRARY_TEXT.lines + [GO_EXC]),
      json_scenario('Default message field "log"', '', 'log',
                    [PYTHON_EXC, ARBITRARY_TEXT, GO_EXC],
                    [PYTHON_EXC] + ARBITRARY_TEXT.lines + [GO_EXC]),
      json_scenario('Wrongly defined message field', 'doesnotexist', 'mydata',
                    [PYTHON_EXC, ARBITRARY_TEXT, GO_EXC],
                    PYTHON_EXC.lines + ARBITRARY_TEXT.lines + GO_EXC.lines),
      json_scenario('Undefined message field', '', 'mydata',
                    [PYTHON_EXC, ARBITRARY_TEXT, GO_EXC],
                    PYTHON_EXC.lines + ARBITRARY_TEXT.lines + GO_EXC.lines)
    ].each do |s|
      out = []
      buffer = Fluent::TraceAccumulator.new(s.configured_field,
                                            [:all]) { |_, m| out << m }
      feed_json(buffer, s.actual_field, s.input)
      assert_equal(expected_json(s.actual_field, s.output), out, s.desc)
    end
  end

  def test_max_lines_limit
    # Limit is equal to the first part of the exception and forces it to be
    # flushed before the rest of the exception is processed.
    max_lines = JAVA_EXC_PART1.lines.length
    out = []
    buffer = Fluent::TraceAccumulator.new(nil,
                                          [:all],
                                          max_lines: max_lines) do |_, m|
      out << m
    end
    feed_lines(buffer, JAVA_EXC)
    assert_equal([JAVA_EXC_PART1] + JAVA_EXC_PART2.lines, out)
  end

  def test_high_max_bytes_limit
    # Limit is just too small to add one more line to the buffered first part of
    # the exception.
    max_bytes = JAVA_EXC_PART1.length + JAVA_EXC_PART2.lines[0].length - 1
    out = []
    buffer = Fluent::TraceAccumulator.new(nil,
                                          [:all],
                                          max_bytes: max_bytes) do |_, m|
      out << m
    end
    feed_lines(buffer, JAVA_EXC)
    # Check that the trace is flushed after the first part.
    assert_equal([JAVA_EXC_PART1] + JAVA_EXC_PART2.lines, out)
  end

  def test_low_max_bytes_limit
    # Limit is exceeded by the character that follows the buffered first part of
    # the exception.
    max_bytes = JAVA_EXC_PART1.length
    out = []
    buffer = Fluent::TraceAccumulator.new(nil,
                                          [:all],
                                          max_bytes: max_bytes) do |_, m|
      out << m
    end
    feed_lines(buffer, JAVA_EXC)
    # Check that the trace is flushed after the first part.
    assert_equal([JAVA_EXC_PART1] + JAVA_EXC_PART2.lines, out)
  end
end
