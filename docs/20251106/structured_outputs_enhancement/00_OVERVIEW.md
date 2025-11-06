# Structured Outputs Enhancement Initiative - Overview

**Initiative ID:** `structured_outputs_enhancement`
**Date:** November 6, 2025
**Status:** Planning
**Priority:** High
**Estimated Effort:** 8-12 hours

---

## Executive Summary

The Gemini API released significant enhancements to structured outputs on November 5, 2025. This initiative brings `gemini_ex` into full compliance with the updated API specification, adds support for new features, and improves documentation and developer experience around structured JSON output generation.

**Current State:** ✅ Core functionality works, but missing some new features
**Target State:** 🎯 Full API compliance + enhanced DX + comprehensive docs

---

## Background

### What Are Structured Outputs?

Structured outputs enable AI models to generate responses that guarantee adherence to a specific JSON Schema. This is critical for:

- **Data extraction:** Pull specific information from unstructured text
- **Structured classification:** Categorize with predefined schemas
- **Agentic workflows:** Generate data that becomes input to other systems
- **Type safety:** Ensure programmatic parsing without validation failures

### Why This Matters

The November 2025 API update expanded structured outputs to all Gemini models and added powerful new JSON Schema keywords. This makes structured outputs production-ready for enterprise applications requiring guaranteed output formats.

---

## Key Changes in November 2025 API Update

### 1. **Universal Model Support**
- Previously: Limited model availability
- Now: All actively supported Gemini models (2.5 Pro/Flash/Lite, 2.0 Flash/Lite)

### 2. **New JSON Schema Keywords**
- `anyOf` - Union types / conditional structures
- `$ref` - Recursive schemas
- `minimum` / `maximum` - Numeric constraints
- `additionalProperties` - Control extra properties
- `type: 'null'` - Nullable fields
- `prefixItems` - Tuple-like arrays

### 3. **Property Ordering Guarantees**
- Gemini 2.5+: Implicit ordering (preserves schema key order)
- Gemini 2.0: Requires explicit `propertyOrdering` array

### 4. **Enhanced Streaming**
- Streamed chunks are valid partial JSON strings
- Can be concatenated to form complete JSON

### 5. **Better Type Safety**
- More predictable output format
- Reduced parsing errors
- Programmatic refusal detection

---

## Initiative Goals

### Primary Objectives

1. ✅ **API Compliance:** Support all new features from Nov 2025 update
2. 📚 **Documentation:** Comprehensive guides for structured outputs
3. 🎯 **Developer Experience:** Convenience helpers and ergonomic APIs
4. ✨ **Examples:** Real-world use cases and patterns
5. 🧪 **Testing:** Validate all new functionality

### Non-Goals

- Schema generation from Elixir types (future enhancement)
- Client-side schema validation (API handles this)
- Custom schema DSL (keep it simple, use maps)

---

## Implementation Scope

### Code Changes

| Component | Change Type | Effort |
|-----------|------------|--------|
| `GenerationConfig` struct | Add `property_ordering` field | 5 min |
| Coordinator | Support new field in camelCase conversion | 10 min |
| Helper methods | Add `structured_json/2` convenience helper | 15 min |
| Type specs | Update typespecs for new field | 5 min |

### Documentation

| Document | Type | Effort |
|----------|------|--------|
| Structured Outputs Guide | User guide | 2 hours |
| API Reference Updates | Technical docs | 1 hour |
| README Updates | Getting started | 30 min |
| Changelog | Release notes | 15 min |

### Examples

| Example | Purpose | Effort |
|---------|---------|--------|
| Basic structured output | Simple schemas | 30 min |
| Complex schemas | New keywords | 45 min |
| Streaming structured output | Real-time parsing | 30 min |
| Real-world patterns | Data extraction, classification | 1 hour |

### Testing

| Test Suite | Coverage | Effort |
|------------|----------|--------|
| `property_ordering` tests | New field handling | 30 min |
| Schema keyword tests | Validate new features work | 45 min |
| Integration tests | End-to-end validation | 1 hour |
| Streaming tests | Partial JSON validation | 30 min |

**Total Estimated Effort:** 8-12 hours

---

## Success Criteria

### Must Have (P0)
- [x] `property_ordering` field implemented
- [ ] All new JSON Schema keywords validated
- [ ] Comprehensive user guide published
- [ ] At least 3 working examples
- [ ] 95%+ test coverage for new features

### Should Have (P1)
- [ ] Convenience helper for structured JSON
- [ ] Migration guide for existing users
- [ ] Performance benchmarks
- [ ] Error handling guide

### Nice to Have (P2)
- [ ] Video tutorial
- [ ] Interactive schema builder
- [ ] Schema validation helper (client-side)

---

## Risk Assessment

### Low Risk
- ✅ Core functionality already works
- ✅ Changes are additive, not breaking
- ✅ Extensive test coverage exists

### Medium Risk
- ⚠️ Documentation effort may be underestimated
- ⚠️ Need to validate all new keywords work correctly
- ⚠️ Property ordering behavior differs by model version

### Mitigation Strategies
1. Start with code changes (smallest scope)
2. Validate with live API tests early
3. Iterate on docs based on community feedback
4. Create examples first, then extract patterns for docs

---

## Timeline

### Phase 1: Core Implementation (2-3 hours)
- Add `property_ordering` field
- Update coordinator logic
- Add convenience helpers
- Update type specs

### Phase 2: Testing (2-3 hours)
- Write unit tests
- Create integration tests
- Validate with live API
- Performance testing

### Phase 3: Documentation (3-4 hours)
- Write user guide
- Update API reference
- Create examples
- Update README

### Phase 4: Review & Release (1-2 hours)
- Code review
- Documentation review
- Prepare changelog
- Release v0.4.0

**Total Timeline:** 8-12 hours (1-2 days of focused work)

---

## Stakeholder Impact

### Library Users
- ✅ More powerful structured output capabilities
- ✅ Better documentation and examples
- ✅ No breaking changes to existing code

### Library Maintainers
- ✅ Better alignment with official API
- ✅ Reduced support burden (better docs)
- ⚠️ Ongoing maintenance of new examples

### Downstream Projects
- ✅ Can leverage new features immediately
- ✅ Backward compatible
- ✅ Clear migration path

---

## Document Structure

This initiative includes the following technical documents:

1. **`00_OVERVIEW.md`** (this document) - Initiative summary and goals
2. **`01_API_CHANGES.md`** - Detailed API specification changes
3. **`02_IMPLEMENTATION_PLAN.md`** - Step-by-step implementation guide
4. **`03_CODE_CHANGES.md`** - Exact code changes required
5. **`04_TESTING_STRATEGY.md`** - Test coverage and validation approach
6. **`05_DOCUMENTATION_UPDATES.md`** - User-facing documentation plan
7. **`06_EXAMPLES.md`** - Example code and use cases
8. **`07_MIGRATION_GUIDE.md`** - Guide for existing users

---

## Next Steps

1. Review this overview document
2. Read `01_API_CHANGES.md` for technical API details
3. Follow `02_IMPLEMENTATION_PLAN.md` for execution
4. Use `03_CODE_CHANGES.md` for exact code modifications
5. Implement testing per `04_TESTING_STRATEGY.md`
6. Create documentation per `05_DOCUMENTATION_UPDATES.md`
7. Build examples from `06_EXAMPLES.md`
8. Prepare release using `07_MIGRATION_GUIDE.md`

---

## References

- [Gemini API Structured Outputs Documentation](https://ai.google.dev/gemini-api/docs/structured-outputs)
- [Gemini API News - Nov 5, 2025](https://ai.google.dev/gemini-api/docs/structured-outputs/news)
- [JSON Schema Specification](https://json-schema.org/)
- [gemini_ex Current Implementation](../../../lib/gemini/types/common/generation_config.ex)

---

**Document Version:** 1.0
**Last Updated:** November 6, 2025
**Next Review:** Upon completion of implementation
