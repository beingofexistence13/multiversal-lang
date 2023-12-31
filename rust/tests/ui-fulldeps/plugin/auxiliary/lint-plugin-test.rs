// force-host

#![feature(rustc_private)]

extern crate rustc_ast;

// Load rustc as a plugin to get macros
extern crate rustc_driver;
extern crate rustc_lint;
#[macro_use]
extern crate rustc_session;

use rustc_ast::ast;
use rustc_driver::plugin::Registry;
use rustc_lint::{EarlyContext, EarlyLintPass, LintContext};

declare_lint!(TEST_LINT, Warn, "Warn about items named 'lintme'");

declare_lint_pass!(Pass => [TEST_LINT]);

impl EarlyLintPass for Pass {
    fn check_item(&mut self, cx: &EarlyContext, it: &ast::Item) {
        if it.ident.name.as_str() == "lintme" {
            cx.lint(TEST_LINT, "item is named 'lintme'", |lint| lint.set_span(it.span));
        }
    }
}

#[no_mangle]
fn __rustc_plugin_registrar(reg: &mut Registry) {
    reg.lint_store.register_lints(&[&TEST_LINT]);
    reg.lint_store.register_early_pass(|| Box::new(Pass));
}
