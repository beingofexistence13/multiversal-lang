// Part of the Carbon Language project, under the Apache License v2.0 with LLVM
// Exceptions. See /LICENSE for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception

#include "testing/fuzzing/proto_to_carbon.h"

#include <gmock/gmock.h>
#include <gtest/gtest.h>

#include "common/error.h"
#include "testing/fuzzing/carbon.pb.h"

namespace Carbon::Testing {
namespace {

TEST(FuzzerUtilTest, ProtoToCarbon) {
  const ErrorOr<Fuzzing::Carbon> carbon_proto = ParseCarbonTextProto(R"(
    compilation_unit {
      package_statement { package_name: "P" }
      is_api: true
      declarations {
        function {
          name {
            name: "Main"
          }
          param_pattern {}
          return_term {
            kind: Expression
            type { int_type_literal {} }
          }
          body {
            statements {
              return_expression_statement {
                expression { int_literal { value: 0 } }
              }
            }
          }
        }
      }
    })");
  ASSERT_TRUE(carbon_proto.ok());
  static constexpr char SourceCode[] = R"(// Generated by proto_to_carbon.
package P api;

fn Main() -> i32
{
return 0;
}

)";
  EXPECT_THAT(ProtoToCarbon(*carbon_proto, /*maybe_add_main=*/false),
              testing::Eq(SourceCode));
  EXPECT_THAT(ProtoToCarbon(*carbon_proto, /*maybe_add_main=*/true),
              testing::Eq(SourceCode));
}

TEST(FuzzerUtilTest, ParseCarbonTextProtoWithUnknownField) {
  const ErrorOr<Fuzzing::Carbon> carbon_proto = ParseCarbonTextProto(R"(
    compilation_unit {
      garbage: "value"
      declarations {
        choice {
          name {
            name: "Ch"
          }
        }
      }
    })");
  ASSERT_FALSE(carbon_proto.ok());
}

}  // namespace
}  // namespace Carbon::Testing
