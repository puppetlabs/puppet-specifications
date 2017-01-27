Draft replacement for types and providers

Hi *,

I'm currently working on designing a nicer API to replace the current type&provider things. My primary goals are to provide a smooth and simple ruby developer experience for both scripters and coders. Secondary goals were to eliminate server side code, and make puppet 4 data types available.

To showcase my vision, https://gist.github.com/DavidS/430330ae43ba4b51fe34bd27ddbe4bc7 has the apt_key resource from https://github.com/puppetlabs/puppetlabs-apt/blob/master/lib/puppet/type/apt_key.rb and https://github.com/puppetlabs/puppetlabs-apt/blob/master/lib/puppet/provider/apt_key/apt_key.rb ported over.

The `define()` call provides a data-only description of the Type. This is all that is needed on the server side to compile a manifest. Thanks to puppet 4 data type checking, this will already be much more strict (with less effort) than possible with the current APIs.
  
The `implement()` call contains the `current_state = get()` and `set(current_state, target_state, noop)` implementations that will provide a data-driven API to working with resource instances.

Details in no particular order:

* All of this should fit on any unmodified puppet4 installation. It is completely additive and optional. Currently. 

* Type definition
** It is data-only.
** No code runs on the server.
** autorelations are restricted to unmodified attribute values and constant values.
** Refers to puppet data types.
** This information can be re-used in all tooling around displaying/working with types (e.g. puppet-strings, console, ENC, etc.).
** No more `validate` or `munge`! For the edge cases not covered by data types, runtime checking can happen in the implementation on the agent. There it can use local system state (e.g. different mysql versions have different max table length constraints), and it will only fail the part of the resource tree, that is dependent on this error. There is already ample precedent for runtime validation, as most remote resources do not try to replicate the validation their target is already doing anyways.
** It maps 1:1 to the capabilities of PCore, and is similar to the libral interface description (see [libral#1](https://github.com/puppetlabs/libral/pull/2)). This ensures future interoperability between the different parts of the ecosystem.
** Related types can share common attributes by sharing/merging the attribute hashes.

* The implementation are two simple functions `current_state = get()`, and `set(current_state, target_state, noop)`.
** There is no direct dependency on puppet in the implementation.
** The dependencies on the `logger`, `commands`, and similar utilities can be supplied by a small utility library (TBD).
** Calling `r.set(r.get, r.get)` would ensure the current state. This should run without any changes, proving the idempotency of the implementation.
** `get` on its own is already useful for many things, like puppet resource.
** the `current_state` and `target_state` values are lists of simple data structures built up of primitives like strings, numbers, hashes and arrays. They match the schema defined in the type. 
** `set` receives the current state from `get`. While this is necessary for proper operation there is a certain race condition there, if the system state changes between the calls. This is no different than the current state, and implementations are well-equipped to deal with this.
** `set` is called with a list of resources, and can do batching if it is beneficial. This is not yet supported by the agent.

* The logging of updates to the transaction is only a sketch. See the usage of `logger` throughout the example. I've tried different styles for fit.

* Obviously this is not sufficient to cover everything existing types and providers are able to do. For the first iteration we are choosing simplicity over functionality.
** Generating more resource instances for the catalog during compilation (e.g. file#recurse or concat) becomes impossible with a pure data-driven Type. There is still space in the API to add server-side code. 
** Some resources (e.g. file, ssh_authorized_keys, concat) cannot or should not be prefetched. While it might not be convenient, a provider could always return nothing on the `get()` and do a more customized enforce motion in the `set()`.
** With current puppet versions, only "native" data types will be supported, as type aliases do not get pluginsynced. Yet.
** With current puppet versions, `puppet resource` can't load the data types, and therefore will not be able to take full advantage of this. Yet.

* There is some convenient infrastructure (e.g. parsedfile) that needs porting over to this model.

* Testing becomes possible on a complete new level. The test library can know how data is transformed outside the API, and - using the shape of the type - start generating test cases, and checking the actions of the implementation. This will require developer help to isolate the implementation from real systems, but it should go a long way towards reducing the tedium in writing tests.


What do you think about this?


Cheers, David

