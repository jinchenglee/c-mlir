{-# LANGUAGE QuasiQuotes #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE OverloadedStrings #-}
module CMLIR.TranslatorSpec where

import Test.Hspec
import Text.RawString.QQ
import qualified Data.ByteString.UTF8 as BU
import qualified Data.ByteString as BS
import Data.Char
import Data.Maybe
import Data.List
import CMLIR.Parser
import CMLIR.Translator

shouldBeTranslatedAs code ir = do
  let ast = processString code
  output <- case ast of
              Left errs -> return $ show errs
              Right ast -> translateToMLIR defaultOptions ast
  removeEmptyLines (BU.fromString output) `shouldBe` removeEmptyLines ir
  where removeEmptyLines s = 
          BS.intercalate "\n" [l | l <- BS.split (fromIntegral $ ord '\n') s, 
                   [c | c<- BU.toString l, c /= ' '] /= ""]

spec :: Spec
spec = do
  describe "translator" $ do
    it "can translate builtin types" $ do
      [r|
void foo() {
  char v0;
  unsigned char v1;
  short v2;
  unsigned short v3;
  int v4;
  unsigned int v5;
  long v6;
  unsigned long v7;
  float v8;
  double v9;
}
      |] `shouldBeTranslatedAs` [r|
module  {
  func @foo() attributes {llvm.emit_c_interface} {
    %0 = memref.alloca() : memref<i8>
    %1 = memref.alloca() : memref<i8>
    %2 = memref.alloca() : memref<i16>
    %3 = memref.alloca() : memref<i16>
    %4 = memref.alloca() : memref<i32>
    %5 = memref.alloca() : memref<i32>
    %6 = memref.alloca() : memref<i64>
    %7 = memref.alloca() : memref<i64>
    %8 = memref.alloca() : memref<f32>
    %9 = memref.alloca() : memref<f64>
    return
  }
}
      |]
    
    it "can translate static array types" $ do
      [r|
void foo() {
  int v0[4][5];
}
      |] `shouldBeTranslatedAs` [r|
module  {
  func @foo() attributes {llvm.emit_c_interface} {
    %0 = memref.alloca() : memref<4x5xi32>
    return
  }
}
      |]

    it "can translate static array access" $ do
      [r|
void foo() {
  int v0[4][5];
  v0[2][3] = v0[2][1];
}
      |] `shouldBeTranslatedAs` [r|
module  {
  func @foo() attributes {llvm.emit_c_interface} {
    %0 = memref.alloca() : memref<4x5xi32>
    %c2_i32 = arith.constant 2 : i32
    %c1_i32 = arith.constant 1 : i32
    %1 = arith.index_cast %c2_i32 : i32 to index
    %2 = arith.index_cast %c1_i32 : i32 to index
    %3 = memref.load %0[%1, %2] : memref<4x5xi32>
    %c2_i32_0 = arith.constant 2 : i32
    %c3_i32 = arith.constant 3 : i32
    %4 = arith.index_cast %c2_i32_0 : i32 to index
    %5 = arith.index_cast %c3_i32 : i32 to index
    memref.store %3, %0[%4, %5] : memref<4x5xi32>
    return
  }
}
      |]

    it "can translate literals" $ do
      [r|
void foo() {
  char v0 = 'a';
  int v1 = 1;
  long v2 = 1L;
  float v3 = 0.1;
  double v4 = 0.1L;
}
      |] `shouldBeTranslatedAs` [r|
module  {
  func @foo() attributes {llvm.emit_c_interface} {
    %c97_i8 = arith.constant 97 : i8
    %0 = memref.alloca() : memref<i8>
    %c0 = arith.constant 0 : index
    memref.store %c97_i8, %0[] : memref<i8>
    %c1_i32 = arith.constant 1 : i32
    %1 = memref.alloca() : memref<i32>
    %c0_0 = arith.constant 0 : index
    memref.store %c1_i32, %1[] : memref<i32>
    %c1_i64 = arith.constant 1 : i64
    %2 = memref.alloca() : memref<i64>
    %c0_1 = arith.constant 0 : index
    memref.store %c1_i64, %2[] : memref<i64>
    %cst = arith.constant 1.000000e-01 : f32
    %3 = memref.alloca() : memref<f32>
    %c0_2 = arith.constant 0 : index
    memref.store %cst, %3[] : memref<f32>
    %cst_3 = arith.constant 1.000000e-01 : f64
    %4 = memref.alloca() : memref<f64>
    %c0_4 = arith.constant 0 : index
    memref.store %cst_3, %4[] : memref<f64>
    return
  }
}
      |]

    it "can translate int arith operations" $ do
      [r|
void foo() {
  int v0,v1;
  v0 + v1;
  v0 - v1;
  v0 * v1;
  v0 / v1;
  v0 % v1;
}
      |] `shouldBeTranslatedAs` [r|
module  {
  func @foo() attributes {llvm.emit_c_interface} {
    %0 = memref.alloca() : memref<i32>
    %1 = memref.alloca() : memref<i32>
    %2 = memref.load %0[] : memref<i32>
    %3 = memref.load %1[] : memref<i32>
    %4 = arith.addi %2, %3 : i32
    %5 = memref.load %0[] : memref<i32>
    %6 = memref.load %1[] : memref<i32>
    %7 = arith.subi %5, %6 : i32
    %8 = memref.load %0[] : memref<i32>
    %9 = memref.load %1[] : memref<i32>
    %10 = arith.muli %8, %9 : i32
    %11 = memref.load %0[] : memref<i32>
    %12 = memref.load %1[] : memref<i32>
    %13 = arith.divsi %11, %12 : i32
    %14 = memref.load %0[] : memref<i32>
    %15 = memref.load %1[] : memref<i32>
    %16 = arith.remsi %14, %15 : i32
    return
  }
}
      |]

    it "can translate unsigned int arith operations" $ do
      [r|
void foo() {
  unsigned int v0,v1;
  v0 + v1;
  v0 - v1;
  v0 * v1;
  v0 / v1;
  v0 % v1;
}
      |] `shouldBeTranslatedAs` [r|
module  {
  func @foo() attributes {llvm.emit_c_interface} {
    %0 = memref.alloca() : memref<i32>
    %1 = memref.alloca() : memref<i32>
    %2 = memref.load %0[] : memref<i32>
    %3 = memref.load %1[] : memref<i32>
    %4 = arith.addi %2, %3 : i32
    %5 = memref.load %0[] : memref<i32>
    %6 = memref.load %1[] : memref<i32>
    %7 = arith.subi %5, %6 : i32
    %8 = memref.load %0[] : memref<i32>
    %9 = memref.load %1[] : memref<i32>
    %10 = arith.muli %8, %9 : i32
    %11 = memref.load %0[] : memref<i32>
    %12 = memref.load %1[] : memref<i32>
    %13 = arith.divui %11, %12 : i32
    %14 = memref.load %0[] : memref<i32>
    %15 = memref.load %1[] : memref<i32>
    %16 = arith.remui %14, %15 : i32
    return
  }
}
      |]
    
    it "can translate float arith operations" $ do
      [r|
void foo() {
  float v0,v1;
  v0 + v1;
  v0 - v1;
  v0 * v1;
  v0 / v1;
  v0 % v1;
}
      |] `shouldBeTranslatedAs` [r|
module  {
  func @foo() attributes {llvm.emit_c_interface} {
    %0 = memref.alloca() : memref<f32>
    %1 = memref.alloca() : memref<f32>
    %2 = memref.load %0[] : memref<f32>
    %3 = memref.load %1[] : memref<f32>
    %4 = arith.addf %2, %3 : f32
    %5 = memref.load %0[] : memref<f32>
    %6 = memref.load %1[] : memref<f32>
    %7 = arith.subf %5, %6 : f32
    %8 = memref.load %0[] : memref<f32>
    %9 = memref.load %1[] : memref<f32>
    %10 = arith.mulf %8, %9 : f32
    %11 = memref.load %0[] : memref<f32>
    %12 = memref.load %1[] : memref<f32>
    %13 = arith.divf %11, %12 : f32
    %14 = memref.load %0[] : memref<f32>
    %15 = memref.load %1[] : memref<f32>
    %16 = arith.remf %14, %15 : f32
    return
  }
}
      |]

    it "can translate int compare operations" $ do
      [r|
void foo() {
  int v0,v1;
  v0 == v1;
  v0 != v1;
  v0 > v1;
  v0 < v1;
  v0 >= v1;
  v0 <= v1;
}
      |] `shouldBeTranslatedAs` [r|
module  {
  func @foo() attributes {llvm.emit_c_interface} {
    %0 = memref.alloca() : memref<i32>
    %1 = memref.alloca() : memref<i32>
    %2 = memref.load %0[] : memref<i32>
    %3 = memref.load %1[] : memref<i32>
    %4 = arith.cmpi eq, %2, %3 : i32
    %5 = memref.load %0[] : memref<i32>
    %6 = memref.load %1[] : memref<i32>
    %7 = arith.cmpi ne, %5, %6 : i32
    %8 = memref.load %0[] : memref<i32>
    %9 = memref.load %1[] : memref<i32>
    %10 = arith.cmpi sgt, %8, %9 : i32
    %11 = memref.load %0[] : memref<i32>
    %12 = memref.load %1[] : memref<i32>
    %13 = arith.cmpi slt, %11, %12 : i32
    %14 = memref.load %0[] : memref<i32>
    %15 = memref.load %1[] : memref<i32>
    %16 = arith.cmpi sge, %14, %15 : i32
    %17 = memref.load %0[] : memref<i32>
    %18 = memref.load %1[] : memref<i32>
    %19 = arith.cmpi sle, %17, %18 : i32
    return
  }
}
      |]
    
    it "can translate unsigned int compare operations" $ do
      [r|
void foo() {
  unsigned int v0,v1;
  v0 == v1;
  v0 != v1;
  v0 > v1;
  v0 < v1;
  v0 >= v1;
  v0 <= v1;
}
      |] `shouldBeTranslatedAs` [r|
module  {
  func @foo() attributes {llvm.emit_c_interface} {
    %0 = memref.alloca() : memref<i32>
    %1 = memref.alloca() : memref<i32>
    %2 = memref.load %0[] : memref<i32>
    %3 = memref.load %1[] : memref<i32>
    %4 = arith.cmpi eq, %2, %3 : i32
    %5 = memref.load %0[] : memref<i32>
    %6 = memref.load %1[] : memref<i32>
    %7 = arith.cmpi ne, %5, %6 : i32
    %8 = memref.load %0[] : memref<i32>
    %9 = memref.load %1[] : memref<i32>
    %10 = arith.cmpi ugt, %8, %9 : i32
    %11 = memref.load %0[] : memref<i32>
    %12 = memref.load %1[] : memref<i32>
    %13 = arith.cmpi ult, %11, %12 : i32
    %14 = memref.load %0[] : memref<i32>
    %15 = memref.load %1[] : memref<i32>
    %16 = arith.cmpi uge, %14, %15 : i32
    %17 = memref.load %0[] : memref<i32>
    %18 = memref.load %1[] : memref<i32>
    %19 = arith.cmpi ule, %17, %18 : i32
    return
  }
}
      |]

    it "can translate logic operations" $ do
      [r|
void foo() {
  unsigned int v0,v1;
  v0 == v1 && v0 == v1;
  v0 == v1 || v0 == v1;
}
      |] `shouldBeTranslatedAs` [r|
module  {
  func @foo() attributes {llvm.emit_c_interface} {
    %0 = memref.alloca() : memref<i32>
    %1 = memref.alloca() : memref<i32>
    %2 = memref.load %0[] : memref<i32>
    %3 = memref.load %1[] : memref<i32>
    %4 = arith.cmpi eq, %2, %3 : i32
    %5 = memref.load %0[] : memref<i32>
    %6 = memref.load %1[] : memref<i32>
    %7 = arith.cmpi eq, %5, %6 : i32
    %8 = arith.andi %4, %7 : i1
    %9 = memref.load %0[] : memref<i32>
    %10 = memref.load %1[] : memref<i32>
    %11 = arith.cmpi eq, %9, %10 : i32
    %12 = memref.load %0[] : memref<i32>
    %13 = memref.load %1[] : memref<i32>
    %14 = arith.cmpi eq, %12, %13 : i32
    %15 = arith.ori %11, %14 : i1
    return
  }
}
      |]

    it "can translate assign operations" $ do
      [r|
void foo() {
  int i;
  i += 1;
  i -= 1;
  i *= 1;
  i /= 1;
  i %= 1;
  i &= 1;
  i |= 1;
}
      |] `shouldBeTranslatedAs` [r|
module  {
  func @foo() attributes {llvm.emit_c_interface} {
    %0 = memref.alloca() : memref<i32>
    %1 = memref.load %0[] : memref<i32>
    %c1_i32 = arith.constant 1 : i32
    %2 = arith.addi %1, %c1_i32 : i32
    memref.store %2, %0[] : memref<i32>
    %3 = memref.load %0[] : memref<i32>
    %c1_i32_0 = arith.constant 1 : i32
    %4 = arith.subi %3, %c1_i32_0 : i32
    memref.store %4, %0[] : memref<i32>
    %5 = memref.load %0[] : memref<i32>
    %c1_i32_1 = arith.constant 1 : i32
    %6 = arith.muli %5, %c1_i32_1 : i32
    memref.store %6, %0[] : memref<i32>
    %7 = memref.load %0[] : memref<i32>
    %c1_i32_2 = arith.constant 1 : i32
    %8 = arith.divsi %7, %c1_i32_2 : i32
    memref.store %8, %0[] : memref<i32>
    %9 = memref.load %0[] : memref<i32>
    %c1_i32_3 = arith.constant 1 : i32
    %10 = arith.remsi %9, %c1_i32_3 : i32
    memref.store %10, %0[] : memref<i32>
    %11 = memref.load %0[] : memref<i32>
    %c1_i32_4 = arith.constant 1 : i32
    %12 = arith.andi %11, %c1_i32_4 : i32
    memref.store %12, %0[] : memref<i32>
    %13 = memref.load %0[] : memref<i32>
    %c1_i32_5 = arith.constant 1 : i32
    %14 = arith.ori %13, %c1_i32_5 : i32
    memref.store %14, %0[] : memref<i32>
    return
  }
}
      |]
    
    it "can translate function arguments" $ do
      [r|
void foo(int arg0, float arg1) {
}
      |] `shouldBeTranslatedAs` [r|
module  {
  func @foo(%arg0: i32, %arg1: f32) attributes {llvm.emit_c_interface} {
    return
  }
}
      |]

    it "can translate function call" $ do
      [r|
int bar(int arg0) {
  return arg0;
}
void foo(int arg0, float arg1) {
  bar(arg0);
}
      |] `shouldBeTranslatedAs` [r|
module  {
  func @bar(%arg0: i32) -> i32 attributes {llvm.emit_c_interface} {
    return %arg0 : i32
  }
  func @foo(%arg0: i32, %arg1: f32) attributes {llvm.emit_c_interface} {
    %0 = call @bar(%arg0) : (i32) -> i32
    return
  }
}
      |]
    
    it "can translate extern functions" $ do
      [r|
int bar(int arg0);
void foo(int arg0, float arg1) {
  bar(arg0) + 1;
}
      |] `shouldBeTranslatedAs` [r|
module  {
  func private @bar(i32) -> i32
  func @foo(%arg0: i32, %arg1: f32) attributes {llvm.emit_c_interface} {
    %0 = call @bar(%arg0) : (i32) -> i32
    %c1_i32 = arith.constant 1 : i32
    %1 = arith.addi %0, %c1_i32 : i32
    return
  }
}
      |]

    it "can translate for loop to affine for" $ do
      [r|
void foo() {
  for (int i=0; i < 10; i += 2) {
  }
}
      |] `shouldBeTranslatedAs` [r|
module  {
  func @foo() attributes {llvm.emit_c_interface} {
    affine.for %arg0 = 0 to 10 step 2 {
      %0 = arith.index_cast %arg0 : index to i32
    }
    return
  }
}
      |]

    it "can translate for loop to scf for" $ do
      [r|
void foo() {
  int j = 0;
  for (int i=j; i < 10; i += 2) {
  }
}
      |] `shouldBeTranslatedAs` [r|
module  {
  func @foo() attributes {llvm.emit_c_interface} {
    %c0_i32 = arith.constant 0 : i32
    %0 = memref.alloca() : memref<i32>
    %c0 = arith.constant 0 : index
    memref.store %c0_i32, %0[] : memref<i32>
    %1 = memref.load %0[] : memref<i32>
    %c10_i32 = arith.constant 10 : i32
    %c2_i32 = arith.constant 2 : i32
    %2 = arith.index_cast %1 : i32 to index
    %3 = arith.index_cast %c10_i32 : i32 to index
    %4 = arith.index_cast %c2_i32 : i32 to index
    scf.for %arg0 = %2 to %3 step %4 {
      %5 = arith.index_cast %arg0 : index to i32
    }
    return
  }
}
      |]
    
    it "can translate any for loop to scf while" $ do
      [r|
void foo() {
  for (int i=0; i>2; i+=1) {
  }
}
      |] `shouldBeTranslatedAs` [r|
module  {
  func @foo() attributes {llvm.emit_c_interface} {
    %c0_i32 = arith.constant 0 : i32
    %0 = memref.alloca() : memref<i32>
    %c0 = arith.constant 0 : index
    memref.store %c0_i32, %0[] : memref<i32>
    scf.while : () -> () {
      %1 = memref.load %0[] : memref<i32>
      %c2_i32 = arith.constant 2 : i32
      %2 = arith.cmpi sgt, %1, %c2_i32 : i32
      scf.condition(%2)
    } do {
      %1 = memref.load %0[] : memref<i32>
      %c1_i32 = arith.constant 1 : i32
      %2 = arith.addi %1, %c1_i32 : i32
      memref.store %2, %0[] : memref<i32>
      scf.yield
    }
    return
  }
}
      |]

    it "can translate while to scf while" $ do
      [r|
void foo() {
  int i =0;
  while (i< 10) {
    i += 1;
  }
}
      |] `shouldBeTranslatedAs` [r|
module  {
  func @foo() attributes {llvm.emit_c_interface} {
    %c0_i32 = arith.constant 0 : i32
    %0 = memref.alloca() : memref<i32>
    %c0 = arith.constant 0 : index
    memref.store %c0_i32, %0[] : memref<i32>
    scf.while : () -> () {
      %1 = memref.load %0[] : memref<i32>
      %c10_i32 = arith.constant 10 : i32
      %2 = arith.cmpi slt, %1, %c10_i32 : i32
      scf.condition(%2)
    } do {
      %1 = memref.load %0[] : memref<i32>
      %c1_i32 = arith.constant 1 : i32
      %2 = arith.addi %1, %c1_i32 : i32
      memref.store %2, %0[] : memref<i32>
      scf.yield
    }
    return
  }
}
      |]

    it "can translate do-while to scf while" $ do
      [r|
void foo() {
  int i =0;
  do {
    i += 1;
  } while (i<10);
}
      |] `shouldBeTranslatedAs` [r|
module  {
  func @foo() attributes {llvm.emit_c_interface} {
    %c0_i32 = arith.constant 0 : i32
    %0 = memref.alloca() : memref<i32>
    %c0 = arith.constant 0 : index
    memref.store %c0_i32, %0[] : memref<i32>
    %1 = memref.load %0[] : memref<i32>
    %c1_i32 = arith.constant 1 : i32
    %2 = arith.addi %1, %c1_i32 : i32
    memref.store %2, %0[] : memref<i32>
    scf.while : () -> () {
      %3 = memref.load %0[] : memref<i32>
      %c10_i32 = arith.constant 10 : i32
      %4 = arith.cmpi slt, %3, %c10_i32 : i32
      scf.condition(%4)
    } do {
      %3 = memref.load %0[] : memref<i32>
      %c1_i32_0 = arith.constant 1 : i32
      %4 = arith.addi %3, %c1_i32_0 : i32
      memref.store %4, %0[] : memref<i32>
      scf.yield
    }
    return
  }
}
      |]

    it "can translate ifelse to scf if" $ do
      [r|
void foo() {
  int i,j;
  if (i > j) {
  } else {
  }
}
      |] `shouldBeTranslatedAs` [r|
module  {
  func @foo() attributes {llvm.emit_c_interface} {
    %0 = memref.alloca() : memref<i32>
    %1 = memref.alloca() : memref<i32>
    %2 = memref.load %0[] : memref<i32>
    %3 = memref.load %1[] : memref<i32>
    %4 = arith.cmpi sgt, %2, %3 : i32
    scf.if %4 {
    } else {
    }
    return
  }
}
      |]

    it "can translate if to scf if" $ do
      [r|
void foo() {
  int i,j;
  if (i > j) {
  }
}
      |] `shouldBeTranslatedAs` [r|
module  {
  func @foo() attributes {llvm.emit_c_interface} {
    %0 = memref.alloca() : memref<i32>
    %1 = memref.alloca() : memref<i32>
    %2 = memref.load %0[] : memref<i32>
    %3 = memref.load %1[] : memref<i32>
    %4 = arith.cmpi sgt, %2, %3 : i32
    scf.if %4 {
    }
    return
  }
}
      |]

    it "can translate nested for/if" $ do
      [r|
void foo() {
  int i,j;
  for (int i=0; i<10; i+=1) {
    if (i > j) {
    }
  }
}
      |] `shouldBeTranslatedAs` [r|
module  {
  func @foo() attributes {llvm.emit_c_interface} {
    %0 = memref.alloca() : memref<i32>
    %1 = memref.alloca() : memref<i32>
    affine.for %arg0 = 0 to 10 {
      %2 = arith.index_cast %arg0 : index to i32
      %3 = memref.load %1[] : memref<i32>
      %4 = arith.cmpi sgt, %2, %3 : i32
      scf.if %4 {
      }
    }
    return
  }
}
      |]
    
    it "can translate nested for/for" $ do
      [r|
void foo() {
  for (int i=0; i<10; i+=1) {
    for (int j=0; j<10; j+=2) {
    }
  }
}
      |] `shouldBeTranslatedAs` [r|
module  {
  func @foo() attributes {llvm.emit_c_interface} {
    affine.for %arg0 = 0 to 10 {
      %0 = arith.index_cast %arg0 : index to i32
      affine.for %arg1 = 0 to 10 step 2 {
        %1 = arith.index_cast %arg1 : index to i32
      }
    }
    return
  }
}
      |]

    it "can translate nested if/for" $ do
      [r|
void foo() {
  int i, j;
  if (i != j) {
    for (int j=0; j<10; j+=2) {
    }
  }
}
      |] `shouldBeTranslatedAs` [r|
module  {
  func @foo() attributes {llvm.emit_c_interface} {
    %0 = memref.alloca() : memref<i32>
    %1 = memref.alloca() : memref<i32>
    %2 = memref.load %0[] : memref<i32>
    %3 = memref.load %1[] : memref<i32>
    %4 = arith.cmpi ne, %2, %3 : i32
    scf.if %4 {
      affine.for %arg0 = 0 to 10 step 2 {
        %5 = arith.index_cast %arg0 : index to i32
      }
    }
    return
  }
}
      |]

    it "can translate cast to integer" $ do
      [r|
void foo() {
  char v0;
  short v1;
  int v2;
  long v3;
  float v4;
  double v5;
  (char)v0;
  (char)v1;
  (char)v2;
  (char)v3;
  (char)v4;
  (char)v5;
  (short)v0;
  (short)v1;
  (short)v2;
  (short)v3;
  (short)v4;
  (short)v5;
  (int)v0;
  (int)v1;
  (int)v2;
  (int)v3;
  (int)v4;
  (int)v5;
  (long)v0;
  (long)v1;
  (long)v2;
  (long)v3;
  (long)v4;
  (long)v5;
}
      |] `shouldBeTranslatedAs` [r|
module  {
  func @foo() attributes {llvm.emit_c_interface} {
    %0 = memref.alloca() : memref<i8>
    %1 = memref.alloca() : memref<i16>
    %2 = memref.alloca() : memref<i32>
    %3 = memref.alloca() : memref<i64>
    %4 = memref.alloca() : memref<f32>
    %5 = memref.alloca() : memref<f64>
    %6 = memref.load %0[] : memref<i8>
    %7 = memref.load %1[] : memref<i16>
    %8 = arith.trunci %7 : i16 to i8
    %9 = memref.load %2[] : memref<i32>
    %10 = arith.trunci %9 : i32 to i8
    %11 = memref.load %3[] : memref<i64>
    %12 = arith.trunci %11 : i64 to i8
    %13 = memref.load %4[] : memref<f32>
    %14 = arith.fptosi %13 : f32 to i32
    %15 = arith.trunci %14 : i32 to i8
    %16 = memref.load %5[] : memref<f64>
    %17 = arith.fptosi %16 : f64 to i64
    %18 = arith.trunci %17 : i64 to i8
    %19 = memref.load %0[] : memref<i8>
    %20 = arith.extsi %19 : i8 to i16
    %21 = memref.load %1[] : memref<i16>
    %22 = memref.load %2[] : memref<i32>
    %23 = arith.trunci %22 : i32 to i16
    %24 = memref.load %3[] : memref<i64>
    %25 = arith.trunci %24 : i64 to i16
    %26 = memref.load %4[] : memref<f32>
    %27 = arith.fptosi %26 : f32 to i32
    %28 = arith.trunci %27 : i32 to i16
    %29 = memref.load %5[] : memref<f64>
    %30 = arith.fptosi %29 : f64 to i64
    %31 = arith.trunci %30 : i64 to i16
    %32 = memref.load %0[] : memref<i8>
    %33 = arith.extsi %32 : i8 to i32
    %34 = memref.load %1[] : memref<i16>
    %35 = arith.extsi %34 : i16 to i32
    %36 = memref.load %2[] : memref<i32>
    %37 = memref.load %3[] : memref<i64>
    %38 = arith.trunci %37 : i64 to i32
    %39 = memref.load %4[] : memref<f32>
    %40 = arith.fptosi %39 : f32 to i32
    %41 = memref.load %5[] : memref<f64>
    %42 = arith.fptosi %41 : f64 to i64
    %43 = arith.trunci %42 : i64 to i32
    %44 = memref.load %0[] : memref<i8>
    %45 = arith.extsi %44 : i8 to i64
    %46 = memref.load %1[] : memref<i16>
    %47 = arith.extsi %46 : i16 to i64
    %48 = memref.load %2[] : memref<i32>
    %49 = arith.extsi %48 : i32 to i64
    %50 = memref.load %3[] : memref<i64>
    %51 = memref.load %4[] : memref<f32>
    %52 = arith.fptosi %51 : f32 to i32
    %53 = arith.extsi %52 : i32 to i64
    %54 = memref.load %5[] : memref<f64>
    %55 = arith.fptosi %54 : f64 to i64
    return
  }
}
      |]

    it "can translate cast to float" $ do
      [r|
void foo() {
  char v0;
  short v1;
  int v2;
  long v3;
  float v4;
  double v5;
  (float)v0;
  (float)v1;
  (float)v2;
  (float)v3;
  (float)v4;
  (float)v5;
  (double)v0;
  (double)v1;
  (double)v2;
  (double)v3;
  (double)v4;
  (double)v5;
}
      |] `shouldBeTranslatedAs` [r|
module  {
  func @foo() attributes {llvm.emit_c_interface} {
    %0 = memref.alloca() : memref<i8>
    %1 = memref.alloca() : memref<i16>
    %2 = memref.alloca() : memref<i32>
    %3 = memref.alloca() : memref<i64>
    %4 = memref.alloca() : memref<f32>
    %5 = memref.alloca() : memref<f64>
    %6 = memref.load %0[] : memref<i8>
    %7 = arith.extsi %6 : i8 to i32
    %8 = arith.sitofp %7 : i32 to f32
    %9 = memref.load %1[] : memref<i16>
    %10 = arith.extsi %9 : i16 to i32
    %11 = arith.sitofp %10 : i32 to f32
    %12 = memref.load %2[] : memref<i32>
    %13 = arith.sitofp %12 : i32 to f32
    %14 = memref.load %3[] : memref<i64>
    %15 = arith.trunci %14 : i64 to i32
    %16 = arith.sitofp %15 : i32 to f32
    %17 = memref.load %4[] : memref<f32>
    %18 = memref.load %5[] : memref<f64>
    %19 = arith.truncf %18 : f64 to f32
    %20 = memref.load %0[] : memref<i8>
    %21 = arith.extsi %20 : i8 to i64
    %22 = arith.sitofp %21 : i64 to f64
    %23 = memref.load %1[] : memref<i16>
    %24 = arith.extsi %23 : i16 to i64
    %25 = arith.sitofp %24 : i64 to f64
    %26 = memref.load %2[] : memref<i32>
    %27 = arith.extsi %26 : i32 to i64
    %28 = arith.sitofp %27 : i64 to f64
    %29 = memref.load %3[] : memref<i64>
    %30 = arith.sitofp %29 : i64 to f64
    %31 = memref.load %4[] : memref<f32>
    %32 = arith.extf %31 : f32 to f64
    %33 = memref.load %5[] : memref<f64>
    return
  }
}
      |]

    it "can translate post/pre/inc/dec" $ do
      [r|
void foo() {
  int v0;
  ++v0;
  --v0;
  v0++;
  v0--;
}
      |] `shouldBeTranslatedAs` [r|
module  {
  func @foo() attributes {llvm.emit_c_interface} {
    %0 = memref.alloca() : memref<i32>
    %1 = memref.load %0[] : memref<i32>
    %c1_i32 = arith.constant 1 : i32
    %2 = arith.addi %1, %c1_i32 : i32
    memref.store %2, %0[] : memref<i32>
    %3 = memref.load %0[] : memref<i32>
    %4 = memref.load %0[] : memref<i32>
    %c1_i32_0 = arith.constant 1 : i32
    %5 = arith.subi %4, %c1_i32_0 : i32
    memref.store %5, %0[] : memref<i32>
    %6 = memref.load %0[] : memref<i32>
    %7 = memref.load %0[] : memref<i32>
    %8 = memref.load %0[] : memref<i32>
    %c1_i32_1 = arith.constant 1 : i32
    %9 = arith.addi %8, %c1_i32_1 : i32
    memref.store %9, %0[] : memref<i32>
    %10 = memref.load %0[] : memref<i32>
    %11 = memref.load %0[] : memref<i32>
    %c1_i32_2 = arith.constant 1 : i32
    %12 = arith.subi %11, %c1_i32_2 : i32
    memref.store %12, %0[] : memref<i32>
    return
  }
}
      |]
    
    it "can translate plus/minus" $ do
      [r|
void foo() {
  int v0;
  +v0;
  -v0;
  float v1;
  +v1;
  -v1;
}
      |] `shouldBeTranslatedAs` [r|
module  {
  func @foo() attributes {llvm.emit_c_interface} {
    %0 = memref.alloca() : memref<i32>
    %1 = memref.load %0[] : memref<i32>
    %2 = memref.load %0[] : memref<i32>
    %c0_i32 = arith.constant 0 : i32
    %3 = arith.subi %c0_i32, %2 : i32
    %4 = memref.alloca() : memref<f32>
    %5 = memref.load %4[] : memref<f32>
    %6 = memref.load %4[] : memref<f32>
    %7 = arith.negf %6 : f32
    return
  }
}
      |]
    
    it "can translate not" $ do
      [r|
void foo() {
  int v0;
  ! (v0 == v0);
}
      |] `shouldBeTranslatedAs` [r|
module  {
  func @foo() attributes {llvm.emit_c_interface} {
    %0 = memref.alloca() : memref<i32>
    %1 = memref.load %0[] : memref<i32>
    %2 = memref.load %0[] : memref<i32>
    %3 = arith.cmpi eq, %1, %2 : i32
    %false = arith.constant false
    %true = arith.constant true
    %4 = arith.subi %false, %true : i1
    %5 = arith.xori %4, %3 : i1
    return
  }
}
      |]
    
    it "can translate pointer" $ do
      [r|
void foo() {
  int *v0;
  *v0 + 1;
}
      |] `shouldBeTranslatedAs` [r|
module  {
  func @foo() attributes {llvm.emit_c_interface} {
    %0 = memref.alloca() : memref<memref<?xi32>>
    %1 = memref.load %0[] : memref<memref<?xi32>>
    %c0 = arith.constant 0 : index
    %2 = memref.load %1[%c0] : memref<?xi32>
    %c1_i32 = arith.constant 1 : i32
    %3 = arith.addi %2, %c1_i32 : i32
    return
  }
}
      |]

    it "can translate pointer index access" $ do
      [r|
void foo() {
  int *v0;
  v0[0] = v0[1];
}
      |] `shouldBeTranslatedAs` [r|
module  {
  func @foo() attributes {llvm.emit_c_interface} {
    %0 = memref.alloca() : memref<memref<?xi32>>
    %c1_i32 = arith.constant 1 : i32
    %1 = arith.index_cast %c1_i32 : i32 to index
    %2 = memref.load %0[] : memref<memref<?xi32>>
    %3 = memref.load %2[%1] : memref<?xi32>
    %c0_i32 = arith.constant 0 : i32
    %4 = arith.index_cast %c0_i32 : i32 to index
    %5 = memref.load %0[] : memref<memref<?xi32>>
    memref.store %3, %5[%4] : memref<?xi32>
    return
  }
}
      |]

    it "can translate pointer deref assign" $ do
      [r|
void main() {
  int *a;
  *a = 1;
}
      |] `shouldBeTranslatedAs` [r|
module  {
  func @main() attributes {llvm.emit_c_interface} {
    %0 = memref.alloca() : memref<memref<?xi32>>
    %1 = memref.load %0[] : memref<memref<?xi32>>
    %c1_i32 = arith.constant 1 : i32
    %c0 = arith.constant 0 : index
    memref.store %c1_i32, %1[%c0] : memref<?xi32>
    return
  }
}
      |]

    it "can translate pointer assign" $ do
      [r|
void foo() {
  char *a;
  char *b;
  a = b;
}
      |] `shouldBeTranslatedAs` [r|
module  {
  func @foo() attributes {llvm.emit_c_interface} {
    %0 = memref.alloca() : memref<memref<?xi8>>
    %1 = memref.alloca() : memref<memref<?xi8>>
    %2 = memref.load %1[] : memref<memref<?xi8>>
    memref.store %2, %0[] : memref<memref<?xi8>>
    return
  }
}
      |]
  
    it "can translate pointer casting" $ do
      [r|
void foo() {
  int *v0;
  (int[3])v0;
}
      |] `shouldBeTranslatedAs` [r|
module  {
  func @foo() attributes {llvm.emit_c_interface} {
    %0 = memref.alloca() : memref<memref<?xi32>>
    %1 = memref.load %0[] : memref<memref<?xi32>>
    %2 = memref.cast %1 : memref<?xi32> to memref<3xi32>
    return
  }
}
      |]
    
    it "can translate enum" $ do
      [r|
enum test {
  A,
  B
};

void foo(enum test a) {
  int v0 = A;
  v0 = B;
}
      |] `shouldBeTranslatedAs` [r|
module  {
  func @foo(%arg0: i32) attributes {llvm.emit_c_interface} {
    %c0_i32 = arith.constant 0 : i32
    %0 = memref.alloca() : memref<i32>
    %c0 = arith.constant 0 : index
    memref.store %c0_i32, %0[] : memref<i32>
    %c1_i32 = arith.constant 1 : i32
    memref.store %c1_i32, %0[] : memref<i32>
    return
  }
}
      |]
    
    it "can translate arg pointer access" $ do
      [r|
void foo(float* input) {
  float a[100];
  for (int i=0; i<100; i+=1) {
    input[i] = a[i];
    a[i] = input[i];
  }
}
      |] `shouldBeTranslatedAs` [r|
module  {
  func @foo(%arg0: memref<?xf32>) attributes {llvm.emit_c_interface} {
    %0 = memref.alloca() : memref<100xf32>
    affine.for %arg1 = 0 to 100 {
      %1 = arith.index_cast %arg1 : index to i32
      %2 = arith.index_cast %1 : i32 to index
      %3 = memref.load %0[%2] : memref<100xf32>
      %4 = arith.index_cast %1 : i32 to index
      memref.store %3, %arg0[%4] : memref<?xf32>
      %5 = arith.index_cast %1 : i32 to index
      %6 = memref.load %arg0[%5] : memref<?xf32>
      %7 = arith.index_cast %1 : i32 to index
      memref.store %6, %0[%7] : memref<100xf32>
    }
    return
  }
}
      |]

    it "can translate __kernel, __global and __local" $ do
      [r|
__kernel void foo(__global float* input, __local float *a) {
  for (int i=0; i<100; i+=1) {
    input[i] = a[i];
    a[i] = input[i];
  }
}
      |] `shouldBeTranslatedAs` [r|
module  {
  func @foo(%arg0: memref<?xf32, 2>, %arg1: memref<?xf32, 1>) attributes {cl.kernel = true, llvm.emit_c_interface} {
    affine.for %arg2 = 0 to 100 {
      %0 = arith.index_cast %arg2 : index to i32
      %1 = arith.index_cast %0 : i32 to index
      %2 = memref.load %arg1[%1] : memref<?xf32, 1>
      %3 = arith.index_cast %0 : i32 to index
      memref.store %2, %arg0[%3] : memref<?xf32, 2>
      %4 = arith.index_cast %0 : i32 to index
      %5 = memref.load %arg0[%4] : memref<?xf32, 2>
      %6 = arith.index_cast %0 : i32 to index
      memref.store %5, %arg1[%6] : memref<?xf32, 1>
    }
    return
  }
}
      |]
    
    it "can translate init list" $ do
      [r|
void foo() {
  int a[2] = {1,2};
}
      |] `shouldBeTranslatedAs` [r|
module  {
  func @foo() attributes {llvm.emit_c_interface} {
    %c1_i32 = arith.constant 1 : i32
    %c2_i32 = arith.constant 2 : i32
    %0 = memref.alloca() : memref<2xi32>
    %c0 = arith.constant 0 : index
    memref.store %c1_i32, %0[%c0] : memref<2xi32>
    %c1 = arith.constant 1 : index
    memref.store %c2_i32, %0[%c1] : memref<2xi32>
    return
  }
}
      |]

    it "can translate malloc/free" $ do
      [r|
void foo() {
  char *v = malloc(10);
  free(v);
}
      |] `shouldBeTranslatedAs` [r|
module  {
  func @foo() attributes {llvm.emit_c_interface} {
    %c10_i32 = arith.constant 10 : i32
    %0 = arith.index_cast %c10_i32 : i32 to index
    %1 = memref.alloc(%0) : memref<?xi8>
    %2 = memref.alloca() : memref<memref<?xi8>>
    %c0 = arith.constant 0 : index
    memref.store %1, %2[] : memref<memref<?xi8>>
    %3 = memref.load %2[] : memref<memref<?xi8>>
    memref.dealloc %3 : memref<?xi8>
    return
  }
}
      |]
    
    it "can translate array to pointer casting" $ do
      [r|
void foo() {
  char b[10];
  char *c = (char *)b;
}
      |] `shouldBeTranslatedAs` [r|
module  {
  func @foo() attributes {llvm.emit_c_interface} {
    %0 = memref.alloca() : memref<10xi8>
    %1 = memref.cast %0 : memref<10xi8> to memref<?xi8>
    %2 = memref.alloca() : memref<memref<?xi8>>
    %c0 = arith.constant 0 : index
    memref.store %1, %2[] : memref<memref<?xi8>>
    return
  }
}
      |]
