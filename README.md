## CLILogger



#### Server

Just download the executable file from release page and move to your prefer local environment paths with ease.

When running `cli-logger` at the first time, the default configuration file will be generated in `~/.config/clilogger/config.plist` which will be used *in both current and future running session*, that is, `cli-logger` observes the configuration file changes in real time in its lifecycle.

```bash
➜  ~ cli-logger --help
USAGE: cli-logger [--verbose] [<service-name>] [--port <port>]

ARGUMENTS:
  <service-name>          Service name.

OPTIONS:
  --verbose               Show verbose logging of internal service or not.
  -p, --port <port>       The service port number, defaults to automatic.
  -h, --help              Show help information.

```



#### Client

##### Installation

```ruby
pod 'CLILogger'
```



##### Usage

* Swift

  ```swift
  import CLILogger
  
  # Initialize a client and start searching.
  let client = CLILoggingClient()
  client.searchService()
  
  // Send log to server.
  client.log("This is \(Host.current().name ?? "a guest")")
  client.log("See", "you", "next", "time!")
  ```

* Objective-C

  ```objective-c
  #import <CLILogger/CLILogger-Swift.h>
  
  // Required. Start to search the local logging bonjour service, make sure the logging service runs under the same local network with client.
  [CLILoggingClient.shared searchService];
  
  CLILoggingEntity *entity = [[CLILoggingEntity alloc] initWithMessage:@"Hello, world!" flag:DDLogFlagInfo module:[NSString stringWithFormat:@"%s", __FILE__]];
  [CLILoggingClient.shared logWithEntity:entity];
  ```



For diagnosing the internal service from client side, check out the `CLILoggingServiceInfo` class to trace the service status:

```objective-c
CLILoggingServiceInfo.timeout = 3;
CLILoggingServiceInfo.logHandler = ^(DDLogLevel level, NSString *message) {
    printf("%s\n", message.UTF8String);
};
```



#### CocoaLumberjack Integration

Support to forward the log messages to CLILoggingClient easily, take the log filename without extension as module name.

```objective-c

NSString *module = logMessage->_file.lastPathComponent.stringByDeletingPathExtension;
CLILoggingEntity *entity = [[CLILoggingEntity alloc] initWithMessage:message flag:logMessage->_flag module:module];
[CLILoggingClient.shared logWithEntity:entity];
```

It's highly recommended you integrate it with `CococaLumberjack` since we use the `DDLogFlag` type as message flag and `DDLog` functions to trace internal logs inside, too.



#### Issues

For iOS 14, bonjour service on local network is disabled by default, adding the following keys to your client app target’s `Info.plist` makes it available, again.

```xml
<key>NSLocalNetworkUsageDescription</key>
<string>Looking for local TCP Logging Bonjour service</string>
<key>NSBonjourServices</key>
<array>
	<string>_cli-logger-server._tcp.</string>
</array>
```

Otherwise you will [get error](https://developer.apple.com/forums/thread/653316) `["NSNetServicesErrorDomain": 10, "NSNetServicesErrorCode": -72000]`.



#### Dependency

* [CocoaAsyncSocket](https://github.com/robbiehanson/CocoaAsyncSocket)
* [CocoaLumberjack](https://github.com/CocoaLumberjack/CocoaLumberjack)
* [Rainbow](https://github.com/onevcat/Rainbow)

