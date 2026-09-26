.PHONY: help check smoke setup fmt install-macos install-debian install-centos

help:
	@echo "Targets:"
	@echo "  make check           - Run non-destructive dotfiles checks"
	@echo "  make smoke           - Run full checks including Neovim startup smoke test"
	@echo "  make setup           - Symlink configs and bootstrap shell deps"
	@echo "  make fmt             - Format Neovim Lua config with stylua"
	@echo "  make install-macos   - Install/upgrade macOS tooling"
	@echo "  make install-debian  - Install Debian/Ubuntu tooling"
	@echo "  make install-centos  - Install CentOS tooling"

check:
	bash bin/check.sh

smoke:
	RUN_NVIM_SMOKE=1 bash bin/check.sh

setup:
	bash bin/quick_setup.sh

fmt:
	stylua nvim

install-macos:
	bash bin/new_macos.sh

install-debian:
	bash bin/new_debian.sh

install-centos:
	bash bin/new_centos.sh
