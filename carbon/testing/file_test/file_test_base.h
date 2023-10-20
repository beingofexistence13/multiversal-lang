// Part of the Carbon Language project, under the Apache License v2.0 with LLVM
// Exceptions. See /LICENSE for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception

#ifndef CARBON_TESTING_FILE_TEST_FILE_TEST_BASE_H_
#define CARBON_TESTING_FILE_TEST_FILE_TEST_BASE_H_

#include <gmock/gmock.h>
#include <gtest/gtest.h>

#include <functional>

#include "common/error.h"
#include "common/ostream.h"
#include "llvm/ADT/SmallString.h"
#include "llvm/ADT/SmallVector.h"
#include "llvm/ADT/StringRef.h"
#include "llvm/Support/VirtualFileSystem.h"
#include "testing/file_test/autoupdate.h"

namespace Carbon::Testing {

// A framework for testing files. See README.md for documentation.
class FileTestBase : public testing::Test {
 public:
  struct TestFile {
    explicit TestFile(std::string filename, llvm::StringRef content)
        : filename(std::move(filename)), content(content) {}

    friend void PrintTo(const TestFile& f, std::ostream* os) {
      // Print content escaped.
      llvm::raw_os_ostream os_wrap(*os);
      os_wrap << "TestFile(" << f.filename << ", \"";
      os_wrap.write_escaped(f.content);
      os_wrap << "\")";
    }

    std::string filename;
    llvm::StringRef content;
  };

  // Provided for child class convenience.
  using LineNumberReplacement = FileTestAutoupdater::LineNumberReplacement;

  explicit FileTestBase(llvm::StringRef test_name) : test_name_(test_name) {}

  // Implemented by children to run the test. For example, TestBody validates
  // stdout and stderr. Children should use fs for file content, and may add
  // more files.
  //
  // Any test expectations should be called from ValidateRun, not Run.
  //
  // The return value should be an error if there was an abnormal error. It
  // should be true if a binary would return EXIT_SUCCESS, and false for
  // EXIT_FAILURE (which is a test success for `fail_*` tests).
  virtual auto Run(const llvm::SmallVector<llvm::StringRef>& test_args,
                   llvm::vfs::InMemoryFileSystem& fs,
                   llvm::raw_pwrite_stream& stdout,
                   llvm::raw_pwrite_stream& stderr) -> ErrorOr<bool> = 0;

  // Implemented by children to do post-Run test expectations. Only called when
  // testing. Does not need to be provided if only CHECK test expectations are
  // used.
  virtual auto ValidateRun() -> void {}

  // Returns default arguments. Only called when a file doesn't set ARGS.
  virtual auto GetDefaultArgs() -> llvm::SmallVector<std::string> = 0;

  // Returns a regex to match the default file when a line may not be present.
  // May return nullptr if unused. If GetLineNumberReplacements returns an entry
  // with has_file=false, this is required.
  virtual auto GetDefaultFileRE(llvm::ArrayRef<llvm::StringRef> /*filenames*/)
      -> std::optional<RE2> {
    return std::nullopt;
  }

  // Returns replacement information for line numbers. See LineReplacement for
  // construction.
  virtual auto GetLineNumberReplacements(
      llvm::ArrayRef<llvm::StringRef> filenames)
      -> llvm::SmallVector<LineNumberReplacement>;

  // Optionally allows children to provide extra replacements for autoupdate.
  virtual auto DoExtraCheckReplacements(std::string& /*check_line*/) -> void {}

  // Runs a test and compares output. This keeps output split by line so that
  // issues are a little easier to identify by the different line.
  auto TestBody() -> void final;

  // Runs the test and autoupdates checks. Returns true if updated.
  auto Autoupdate() -> ErrorOr<bool>;

  // Returns the name of the test (relative to the repo root).
  auto test_name() const -> llvm::StringRef { return test_name_; }

 private:
  // Encapsulates test context generated by processing and running.
  struct TestContext {
    // The input test file content. Other parts may reference this.
    std::string input_content;

    // Lines which don't contain CHECKs, and thus need to be retained by
    // autoupdate. Their file and line numbers are attached.
    //
    // If there are splits, then the splitting line is in the respective file.
    // For N splits, the 0th file is the parts of the input file which are not
    // in any split, plus one file per split file.
    llvm::SmallVector<FileTestLine> non_check_lines;

    // Whether there are splits.
    bool has_splits = false;

    // Arguments for the test, generated from ARGS.
    llvm::SmallVector<std::string> test_args;

    // Files in the test, generated by content and splits.
    llvm::SmallVector<TestFile> test_files;

    // The location of the autoupdate marker, for autoupdated files.
    std::optional<int> autoupdate_line_number;

    // Whether checks are a subset, generated from SET-CHECK-SUBSET.
    bool check_subset = false;

    // stdout and stderr based on CHECK lines in the file.
    llvm::SmallVector<testing::Matcher<std::string>> expected_stdout;
    llvm::SmallVector<testing::Matcher<std::string>> expected_stderr;

    // stdout and stderr from Run. 16 is arbitrary but a required value.
    llvm::SmallString<16> stdout;
    llvm::SmallString<16> stderr;

    // Whether Run exited with success.
    bool exit_with_success = false;
  };

  // Processes the test file and runs the test. Returns an error if something
  // went wrong.
  auto ProcessTestFileAndRun(TestContext& context) -> ErrorOr<Success>;

  // Does replacements in ARGS for %s and %t.
  auto DoArgReplacements(llvm::SmallVector<std::string>& test_args,
                         const llvm::SmallVector<TestFile>& test_files)
      -> ErrorOr<Success>;

  // Processes the test input, producing test files and expected output.
  auto ProcessTestFile(TestContext& context) -> ErrorOr<Success>;

  // Transforms an expectation on a given line from `FileCheck` syntax into a
  // standard regex matcher.
  static auto TransformExpectation(int line_index, llvm::StringRef in)
      -> ErrorOr<testing::Matcher<std::string>>;

  // Runs the FileTestAutoupdater, returning the result.
  auto RunAutoupdater(const TestContext& context, bool dry_run) -> bool;

  llvm::StringRef test_name_;
};

// Aggregate a name and factory function for tests using this framework.
struct FileTestFactory {
  // The test fixture name.
  const char* name;

  // A factory function for tests.
  std::function<FileTestBase*(llvm::StringRef path)> factory_fn;
};

// Must be implemented by the individual file_test to initialize tests.
//
// We can't use INSTANTIATE_TEST_CASE_P because of ordering issues between
// container initialization and test instantiation by InitGoogleTest, but this
// also allows us more flexibility in execution.
//
// The `CARBON_FILE_TEST_FACTOR` macro below provides a standard, convenient way
// to implement this function.
extern auto GetFileTestFactory() -> FileTestFactory;

// Provides a standard GetFileTestFactory implementation.
#define CARBON_FILE_TEST_FACTORY(Name)                                   \
  auto GetFileTestFactory()->FileTestFactory {                           \
    return {#Name, [](llvm::StringRef path) { return new Name(path); }}; \
  }

}  // namespace Carbon::Testing

#endif  // CARBON_TESTING_FILE_TEST_FILE_TEST_BASE_H_