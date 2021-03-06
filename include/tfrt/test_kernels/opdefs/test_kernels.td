// Copyright 2020 The TensorFlow Runtime Authors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

//===- test_kernels.td ----------------------------------------------------===//
//
// Operation definitions for test_kernels.
//
//===----------------------------------------------------------------------===//

#ifdef TEST_OPS
#else
#define TEST_OPS

include "tfrt/tfrt_op_base.td"
include "mlir/Interfaces/SideEffectInterfaces.td"

// "tfrt_test. dialect
def Test_Dialect : Dialect {
  let name = "tfrt_test";

  let description = [{
    The Test dialect.

    This dialect contains common test operations.
  }];

  let cppNamespace = "test";
}

// Base class for Test dialect ops.
class Test_Op<string mnemonic, list<OpTrait> traits = []> :
    Op<Test_Dialect, mnemonic, !listconcat(traits, [IsolatedFromAbove])> {

  // Each registered op in the Test namespace needs to provide all of a printer,
  // parser and verifier.
  let printer = [{ return tfrt::test::print(p, *this); }];
  let verifier = [{ return tfrt::test::verify(*this); }];
  let parser = [{ return tfrt::test::parse$cppClass(parser, result); }];
}

def DoAsyncOp : Test_Op<"do.async"> {
  let summary = "do.async operation";
  let description = [{
    The "tfrt_test.do.async" operation allows its body to be executed
    asynchronously. It has one region which represents the body.

    The body region takes an arbitrary number of arguments and may return
    arbitrary number of return values, using a `hex.return` operation at the
    end of the region.

    Example:

      tfrt_test.do.async () -> () {
        hex.return
      }

      %res = tfrt_test.do.async () -> (i32) {
        %val = hex.constant.i32 1
        hex.return %val
      }

      %res1, %res2 = tfrt_test.do.async %val1, %val2 : (i32, f32) -> (i32, f32) {
        hex.return %val1, val2 : i32, f32
      }
  }];
  let arguments = (ins Variadic<AnyType>);
  let results = (outs Variadic<AnyType>);
  let regions = (region SizedRegion<1>:$region);
}

def BenchmarkOp : Test_Op<"benchmark"> {
  let summary = "benchmark operation";
  let description = [{
     The "tfrt_test.benchmark" operation benchmarks the performance of an MLIR
     region by executing the given MLIR region repeatedly up to the
     `duratino_secs` seconds or `max_count` times. `num_warmup_runs` specifies
     the number of warm up runs to run the given MLIR region before the
     benchmark starts.

     The target MLIR region can take an arbitrary number of arguments and
     should return exactly one value. The arguments for the MLIR region are
     provided as the operands of the tfrt_test.benchmark op.

     Example:
       tfrt_test.benchmark "add.i32"(%c : i32, %d : f32) max_count = 100, duration_secs = 1 {
         // code for benchmarking
         ...
       }

       tfrt_test.benchmark "add.i32"(%c : i32)
         duration_secs = 1,
         max_count = 100,
         num_warmup_runs = 10 {
         // The MLIR code to be benchmarked goes here.
         // The following code benchmarks the hex.add.i32 kernel.
         %x = hex.add.i32 %c, %c
         // The benchmarked function needs to return exactly one value.
         hex.return %x : i32
       }
  }];

  let regions = (region SizedRegion<1>:$region);

  let arguments = (ins
    Variadic<AnyType>,
    I32Attr:$duration_secs,
    I32Attr:$max_count,
    StrAttr:$name,
    DefaultValuedAttr<I32Attr, "1">:$num_warmup_runs
  );

  let results = (outs ChainType);
}

class Count3Op<string suffix, Type type>
  : Test_Op<"count3." # suffix, [NoSideEffect]> {
  let summary = "tfrt_test.count3 operation";
  let description = [{
     An operation that takes one input x and returns x+1, x+2, x+3 as the
     result.

     Example:
       %1, %2, %3 = test.count3.i32 %0
  }];
  let arguments = (ins type);
  let results = (outs type, type, type);
  let assemblyFormat = "operands attr-dict";
  let verifier = ?;
}

def Count3I32Op : Count3Op<"i32", I32>;
def Count3I64Op : Count3Op<"i64", I64>;


#endif  // TEST_OPS
