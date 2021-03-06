open Core
open Print_typed_ast

let%expect_test "Function overloading different arg names" =
  print_typed_ast
    "
   function int test(bool f) {
      if f { 0} else {1}
    }
    function int test(bool b){
      if b { 1} else {0}
    }

   void main() { 
    test(true)
  }

  " ;
  [%expect {|
    Type error - function test has duplicate definitions in environment |}]

let%expect_test "Function overloading different return types" =
  print_typed_ast
    "
   function bool test(bool b) {
      b
    }
    function int test(bool b){
      if b { 1} else {0}
    }

   void main() { 
    test(true)
  }

  " ;
  [%expect {|
    Type error - function test has duplicate definitions in environment |}]

let%expect_test "Function overloading different param capabilities used" =
  print_typed_ast
    "
     class Foo{
      capability read Bar, local Baz;
      var int f : Bar, Baz;
    }
   function int test(Foo x) {
      x.f
    }
    function int test(Foo{Baz} x){
      x.f := 1
    }

   void main() { 
    let x = new Foo(f:1);
    test(x)
  }

  " ;
  [%expect {|
    Type error - function test has duplicate definitions in environment |}]

let%expect_test "Function overloading borrowed and non-borrowed param used" =
  print_typed_ast
    "
     class Foo{
      capability read Bar, linear Baz;
      var int f : Bar, Baz;
    }
   function int test(borrowed Foo x) {
      x.f
    }
    function int test(Foo x){
      x.f := 1
    }

   void main() { 
    let x = new Foo(f:1);
    test(x)
  }

  " ;
  [%expect {|
    Type error - function test has duplicate definitions in environment |}]

let%expect_test "Method overloading different arg names" =
  print_typed_ast
    "
    class Foo{
      capability read Bar, local Baz;
      var int f : Bar, Baz;

    int test(bool f) : Bar{
      if f { this.f } else {1}
    }
     int test(bool b) : Bar{
      if b { 1} else {this.f}
    }
  }
   void main() { 
    let x = new Foo(f:1);
    x.test(true)
  }

  " ;
  [%expect {|
    Type error - method test has duplicate definitions in environment |}]

let%expect_test "Method overloading different return types" =
  print_typed_ast
    "
     class Foo{
      capability read Bar, local Baz;
      var int f : Bar, Baz;
      bool test(bool b): Bar {
        b
      }
      int test(bool b): Bar{
        if b { 1} else {this.f}
      }
    }
    void main() { 
      let x = new Foo(f:1);
      x.test(true)
    }

  " ;
  [%expect {|
    Type error - method test has duplicate definitions in environment |}]

let%expect_test "Method overloading different param capabilities used" =
  print_typed_ast
    "
     class Foo{
      capability read Bar, local Baz;
      var int f : Bar, Baz;

    int test(Foo x) :Bar {
      x.f
    }
     int test(Foo{Baz} x) : Bar{
      x.f := 1
    }
  }
   void main() { 
    let x = new Foo(f:1);
    x.test(x)
  }

  " ;
  [%expect {|
    Type error - method test has duplicate definitions in environment |}]

let%expect_test "Method overloading borrowed and not borrowed param" =
  print_typed_ast
    "
     class Foo{
      capability read Bar, linear Baz;
      var int f : Bar, Baz;

    int test(borrowed Foo x) :Bar {
      x.f
    }
     int test(Foo x) : Bar{
      x.f := 1
    }
  }
   void main() { 
    let x = new Foo(f:1);
    x.test(x)
  }

  " ;
  [%expect {|
    Type error - method test has duplicate definitions in environment |}]

let%expect_test "Method overloading different method capabilities used" =
  print_typed_ast
    "
     class Foo{
      capability read Bar, local Baz;
      var int f : Bar, Baz;

    int test(int x) : Bar {
      this.f + x
    }
     int test(int x) : Baz{
      this.f := x;
      x
    }
  }
   void main() { 
    let x = new Foo(f:1);
    x.test(x)
  }

  " ;
  [%expect {|
    Type error - method test has duplicate definitions in environment |}]

let%expect_test "Multiple options for overloaded function call" =
  print_typed_ast
    " 
    class Foo {
      capability linear Bar;
      var int f : Bar;
    }
    class Baz extends Foo {
      capability linear Boo;
      var int g : Boo;
    }
    class Choco extends Baz {
      capability linear Late;
      var int g : Late;
    }
    function void f(borrowed Foo x){}
    function void f(borrowed Baz x){}
    void main() {
        let x= new Choco();
        f(x)
    }
  " ;
  [%expect
    {|
      Line:18 Position:9 Type error - function f has multiple matching definition that accepts args of type Choco |}]

let%expect_test "No options for overloaded function call" =
  print_typed_ast
    " 
    class Foo {
      capability linear Bar;
      var int f : Bar;
    }
    class Baz extends Foo {
      capability linear Boo;
      var int g : Boo;
    }
    function void f(Foo x){}
    function void f(Baz x){}
    void main() {
        f(1232)
    }
  " ;
  [%expect
    {|
      Line:13 Position:9 Type error - function f has no matching definition that accepts args of type Int |}]
