# CLILogger



## Server

Just download the executable file from release page and move to your prefer local environment paths with ease.

When running `cli-logger` at the first time, the default configuration file will be generated in `~/.config/clilogger/default.plist` which will be used *in both current and future running session*, that is, `cli-logger` observes the configuration file changes in real time in its lifecycle.

```bash
➜  ~ cli-logger --help
USAGE: cli-logger [--verbose] [<service-name>] [--port <port>]

OPTIONS:
  --verbose               Show verbose logging of internal service or not.
  -s, --service-name <service-name>
                          The service name, defaults to current device host name.
  -p, --port <port>       The service port number, defaults to automatic.
  -f, --file <file>       Configuration file path, defaults to $HOME/.config/clilogger/default.plist.
  -h, --help              Show help information.
```



## Client

##### Installation

```ruby
pod 'CLILogger',, :configurations => ['Debug'], :git => 'https://github.com/CLILogger/CLILogger', :branch => 'master'
```

> It still stays in alpha stage but it’s ready for common usages, I’ll be careful for `master`. :)



#### Usage

* Swift

  ```swift
  import CLILogger
  
  let client = CLILoggingClient.shared
  client.searchService()
  
  // Send log to server.
  client.log("This is \(Host.current().name ?? "a guest")")
  client.log("See", "you", "next", "time!")
  ```
  
* Objective-C

  ```objective-c
  #import <CLILogger/CLILogger-Swift.h>
  
  [CLILoggingClient.shared searchService];
  
  // Initialize entity object and send it to server.
  CLILoggingEntity *entity = [[CLILoggingEntity alloc] initWithMessage:@"Hello, world!" flag:DDLogFlagInfo module:[NSString stringWithFormat:@"%s", __FILE__]];
  [CLILoggingClient.shared logWithEntity:entity];
  ```

For diagnosing the internal service from client side, check out the `CLILoggingServiceInfo` class to trace the service status, same with server side:

```objective-c
CLILoggingServiceInfo.timeout = 3;
CLILoggingServiceInfo.logHandler = ^(DDLogLevel level, NSString *message) {
    printf("%s\n", message.UTF8String);
};
```

When starting to search the local logging bonjour service, make sure the logging service runs under the same local network with client.



## CocoaLumberjack Integration

Support to forward the log messages to CLILoggingClient easily, take the log filename without extension as module name.

```objective-c

NSString *module = logMessage->_file.lastPathComponent.stringByDeletingPathExtension;
CLILoggingEntity *entity = [[CLILoggingEntity alloc] initWithMessage:message flag:logMessage->_flag module:module];
[CLILoggingClient.shared logWithEntity:entity];
```

It's highly recommended you integrate it with `CococaLumberjack` since we use the `DDLogFlag` type as message flag and `DDLog` functions to trace internal logs inside, too.



## Technology

`cli-logger` starts a tcp server with specified name and port for reading all the incoming clients’ arranged data (called `entity` internally), 





Try to discover the logging bonjour service via [Discovery for macOS](https://apps.apple.com/app/discovery-dns-sd-browser/id1381004916?mt=12), [Discovery for iOS](https://apps.apple.com/app/discovery-dns-sd-browser/id305441017) or `dns-sd`:

```bash
➜ dns-sd -B _cli-logger-server._tcp.
```





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



#### Differences [NSLogger](https://github.com/fpillet/NSLogger)





## Dependency

* [CocoaAsyncSocket](https://github.com/robbiehanson/CocoaAsyncSocket)
* [CocoaLumberjack](https://github.com/CocoaLumberjack/CocoaLumberjack)
* [Rainbow](https://github.com/onevcat/Rainbow)



## License

[GPL](./LICENSE.txt)

