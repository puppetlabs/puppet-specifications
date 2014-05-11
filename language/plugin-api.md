Plugin API
===
W.I.P

Type System
---
This section contains typical operations performed in Ruby that deals with the Puppet
Type System.

### Type Algebra

Compute the Puppet Type of an instance:

    t = Puppet::Pops::Types::TypeCalculator.infer(any_object)

Obtain an instance of a type:

    t = Puppet::Pops::Types::TypeFactory.array_of_data()
        
Is the instance of a particular type:

    t = Puppet::Pops::Types::TypeFactory.array_of_data()
    Puppet::Pops::Types::TypeCalculator.instance?(t, some_object)

Is the inferred type assignable (compatible/ narrower) than a particular type?

    data_array_T = Puppet::Pops::Types::TypeFactory.array_of_data()
    t = Puppet::Pops::Types::TypeCalculator.infer(any_object)
    Puppet::Pops::Types::TypeCalculator.assignable?(data_array_T, t)

### Converting Type to/from String

All types can be represented in String form.

Converting to String:

    t.to_s
    
Parsing a String to Type:

    t = Puppet::Pops::Types::TypeParser.new().parse(s)
    # Raises Puppet::ParseError if the string does not represent a valid type

### Iteration of Type

Types that supports enumeration may not support this directly themselves. To iterate
over a type's instances perform this:

     enumerator = Puppet::Pops::Types::TypeCalculator.enumerable(t)
     if enumerator
       enumerator.each {|x| ...}
     else
       # not an enumerable type
     end

(The `Integer` type is enumerable, but currently no other types).

#### Iteration and size

The method `size`, and any method that requires knowing all entries may potentially be
very expensive if all items have to be retrieved in order to compute the size.

(At this point, only the `Integer` type with bound range supports iteration, and it knows its size).

Function
---

### Lambda
A lambda / closure is passed to a function as the very last argument. An implementation should check
if the last argument is a lambda by checking if it responds to `:puppet_lambda`.

    if args[-1].respond_to?(:puppet_lambda)
      closure = args[1]
    else
      closure = nil
    end
    
A call to the lambda is performed by simply passing scope and arguments to it:

    closure.call(scope, arg1, arg2, ...)
   

