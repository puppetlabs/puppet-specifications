Draft replacement for types and providers

Hi *,

The type and provider API has been the bane of my existence since I [started writing native resources](https://github.com/DavidS/puppet-mysql-old/commit/d33c7aa10e3a4bd9e97e947c471ee3ed36e9d1e2). Now, finally, we'll do something about it. I'm currently working on designing a nicer API for types and providers. My primary goals are to provide a smooth and simple ruby developer experience for both scripters and coders. Secondary goals were to eliminate server side code, and make puppet 4 data types available. Currently this is completely aspirational (i.e. no real code has been written), but early private feedback was encouraging.

To showcase my vision, this [gist](https://gist.github.com/DavidS/430330ae43ba4b51fe34bd27ddbe4bc7) has the [apt_key type](https://github.com/puppetlabs/puppetlabs-apt/blob/master/lib/puppet/type/apt_key.rb) and [provider](https://github.com/puppetlabs/puppetlabs-apt/blob/master/lib/puppet/provider/apt_key/apt_key.rb) ported over to my proposal. The second example there is a more long-term teaser on what would become possible with such an API. 

The new API, like the existing, has two parts: the implementation that interacts with the actual resources, a.k.a. the provider, and information about what the implementation is all about. Due to the different usage patterns of the two parts, they need to be passed to puppet in two different calls: 

The `Puppet::SimpleResource.implement()` call receives the `current_state = get()` and `set(current_state, target_state, noop)` methods. `get` returns a list of discovered resources, while `set` takes the target state and enforces those goals on the subject. There is only a single (ruby) object throughout an agent run, that can easily do caching and what ever else is required for a good functioning of the provider. The state descriptions passed around are simple lists of key/value hashes describing resources. This will allow the implementation wide latitude in how to organise itself for simplicity and efficiency.  

The `Puppet::SimpleResource.define()` call provides a data-only description of the Type. This is all that is needed on the server side to compile a manifest. Thanks to puppet 4 data type checking, this will already be much more strict (with less effort) than possible with the current APIs, while providing more automatically readable documentation about the meaning of the attributes. 
  

Details in no particular order:

* All of this should fit on any unmodified puppet4 installation. It is completely additive and optional. Currently.

* The Type definition 
  * It is data-only.
  * Refers to puppet data types.
  * No code runs on the server.
  * This information can be re-used in all tooling around displaying/working with types (e.g. puppet-strings, console, ENC, etc.).
  * autorelations are restricted to unmodified attribute values and constant values.
  * No more `validate` or `munge`! For the edge cases not covered by data types, runtime checking can happen in the implementation on the agent. There it can use local system state (e.g. different mysql versions have different max table length constraints), and it will only fail the part of the resource tree, that is dependent on this error. There is already ample precedent for runtime validation, as most remote resources do not try to replicate the validation their target is already doing anyways.
  * It maps 1:1 to the capabilities of PCore, and is similar to the libral interface description (see [libral#1](https://github.com/puppetlabs/libral/pull/2)). This ensures future interoperability between the different parts of the ecosystem.
  * Related types can share common attributes by sharing/merging the attribute hashes.
  * `defaults`, `read_only`, and similar data about attributes in the definition are mostly aesthetic at the current point in time, but will make for better documentation, and allow more intelligence built on top of this later.

* The implementation are two simple functions `current_state = get()`, and `set(current_state, target_state, noop)`.
  * `get` on its own is already useful for many things, like puppet resource.
  * `set` receives the current state from `get`. While this is necessary for proper operation, there is a certain race condition there, if the system state changes between the calls. This is no different than what current implementations face, and they are well-equipped to deal with this.
  * `set` is called with a list of resources, and can do batching if it is beneficial. This is not yet supported by the agent.
  * the `current_state` and `target_state` values are lists of simple data structures built up of primitives like strings, numbers, hashes and arrays. They match the schema defined in the type.
  * Calling `r.set(r.get, r.get)` would ensure the current state. This should run without any changes, proving the idempotency of the implementation.
  * The ruby instance hosting the `get` and `set` functions is only alive for the duration of an agent transaction. An implementation can provide a `initialize` method to read credentials from the system, and setup other things as required. The single instance is used for all instances of the resource.
  * There is no direct dependency on puppet core libraries in the implementation.
    * While implementations can use utility functions, they are completely optional.
    * The dependencies on the `logger`, `commands`, and similar utilities can be supplied by a small utility library (TBD).

* Having a well-defined small API makes remoting, stacking, proxying, batching, interactive use, and other shenanigans possible, which will make for a interesting time ahead.

* The logging of updates to the transaction is only a sketch. See the usage of `logger` throughout the example. I've tried different styles for fit.
  * the `logger` is the primary way of reporting back information to the log, and the report.
  * results can be streamed for immediate feedback
  * block-based constructs allow detailed logging with little code ("Started X", "X: Doing Something", "X: Success|Failure", with one or two calls, and only one reference to X)
  
* Obviously this is not sufficient to cover everything existing types and providers are able to do. For the first iteration we are choosing simplicity over functionality.
  * Generating more resource instances for the catalog during compilation (e.g. file#recurse or concat) becomes impossible with a pure data-driven Type. There is still space in the API to add server-side code. 
  * Some resources (e.g. file, ssh_authorized_keys, concat) cannot or should not be prefetched. While it might not be convenient, a provider could always return nothing on the `get()` and do a more customized enforce motion in the `set()`.
  * With current puppet versions, only "native" data types will be supported, as type aliases do not get pluginsynced. Yet.
  * With current puppet versions, `puppet resource` can't load the data types, and therefore will not be able to take full advantage of this. Yet.

* There is some "convenient" infrastructure (e.g. parsedfile) that needs porting over to this model.

* Testing becomes possible on a completely new level. The test library can know how data is transformed outside the API, and - using the shape of the type - start generating test cases, and checking the actions of the implementation. This will require developer help to isolate the implementation from real systems, but it should go a long way towards reducing the tedium in writing tests.


What do you think about this?


Cheers, David

