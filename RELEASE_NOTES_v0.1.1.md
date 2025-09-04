# Release Notes - InspectMo v0.1.1

**Release Date**: September 3, 2025  
**Type**: Minor Feature Release  
**Breaking Changes**: None

---

## 🎉 What's New

### ValidationRule Array Utilities
- **Builder Pattern**: Fluent interface for complex validation rule construction
- **Utility Functions**: `appendValidationRule`, `combineValidationRules` for modular validation
- **Type Safety**: Full generic support with compile-time validation
- **Performance**: O(n) linear operations, ~5K-20K instructions

### ICRC16 CandyShared Integration  
- **15 Validation Rules**: Complete metadata validation suite
- **Type Safety**: CandyShared structure validation at compile-time
- **Real-World Ready**: Tested with actual DeFi protocol and file management examples

### Efficient Argument Size Checking
- **`inspectOnlyArgSize`**: O(1) argument size validation without parsing overhead
- **Performance**: Direct blob size access for efficient pre-filtering
- **Integration**: Seamless integration with existing validation pipeline

---

## 🔒 Security & Quality

- ✅ **Security Review Completed**: DoS protection, memory safety, input validation
- ✅ **Production Tested**: 4 deployed canisters validating all features
- ✅ **Performance Validated**: All benchmarks met with excellent efficiency
- ✅ **Zero Breaking Changes**: Fully backward compatible

---

## 📦 Installation

```bash
# Update your mops.toml
mops install inspect-mo@0.1.1
```

---

## 🚀 Migration from v0.1.0

**No migration required!** All changes are purely additive:

1. **New Features Available**: Start using ValidationRule Array Utilities and ICRC16 validation
2. **Existing Code**: Continues to work unchanged  
3. **Dependencies**: Automatically resolved with `mops install`

---

## 📚 Resources

- **API Documentation**: [docs/API.md](docs/API.md)
- **Examples**: [examples/](examples/) - DeFi protocol, file management, user profiles
- **Architecture**: [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)
- **Security Analysis**: [SECURITY_ANALYSIS_v0.1.1.md](SECURITY_ANALYSIS_v0.1.1.md)

---

## 🙏 Acknowledgments

Special thanks to the community for feedback and testing during the development of v0.1.1.

**Ready for Production** ✅
