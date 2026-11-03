#!/usr/bin/env python3
import importlib.util
import pathlib
import unittest

REPO_ROOT = pathlib.Path(__file__).resolve().parents[2]
SCRIPT_PATH = REPO_ROOT / "scripts" / "check_module_migration.py"

spec = importlib.util.spec_from_file_location(
    "check_module_migration",
    SCRIPT_PATH,
)
module = importlib.util.module_from_spec(spec)
assert spec.loader is not None
spec.loader.exec_module(module)


class ModuleMigrationCheckerTests(unittest.TestCase):
    def test_ignores_line_comment_reference(self):
        source = "// Base64URL is supplied by another module\n"
        self.assertFalse(module.contains_symbol_reference(source, "Base64URL"))

    def test_ignores_block_comment_reference(self):
        source = "/* ISO8601Date moved during the refactor. */\n"
        self.assertFalse(module.contains_symbol_reference(source, "ISO8601Date"))

    def test_ignores_substring_lookalikes(self):
        source = """
        let formatter = ISO8601DateFormatter()
        let payload = decodeBase64URL(value)
        """
        self.assertFalse(module.contains_symbol_reference(source, "ISO8601Date"))
        self.assertFalse(module.contains_symbol_reference(source, "Base64URL"))

    def test_finds_real_symbol_reference(self):
        source = "let encoded = Base64URL.encode(data)\n"
        self.assertTrue(module.contains_symbol_reference(source, "Base64URL"))

    def test_detects_private_local_function_definition(self):
        source = "private func decodeBase64URL(_ value: String) -> Data? { nil }\n"
        self.assertTrue(module.is_definition_site(source, "decodeBase64URL"))

    def test_detects_local_protocol_conformance(self):
        source = "private struct Store: SecureStoring {}\n"
        self.assertTrue(module.is_local_conformance_site(source, "SecureStoring"))


if __name__ == "__main__":
    unittest.main()
