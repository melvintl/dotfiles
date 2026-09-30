.PHONY: help check smoke setup setup-dry-run doctor links bootstrap fmt install-macos install-debian install-centos

help:
	@echo "Targets:"
	@echo "  make check           - Run non-destructive dotfiles checks"
	@echo "  make smoke           - Run full checks including Neovim startup smoke test"
	@echo "  make setup           - Symlink configs and bootstrap shell deps"
	@echo "  make setup-dry-run   - Preview setup changes without writing"
	@echo "  make doctor          - Report dotfile link/tool status"
	@echo "  make links           - Symlink/copy configs only"
	@echo "  make bootstrap       - Bootstrap shell deps only"
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

setup-dry-run:
	bash bin/quick_setup.sh --dry-run

doctor:
	bash bin/quick_setup.sh --doctor

links:
	bash bin/quick_setup.sh --links-only

bootstrap:
	bash bin/quick_setup.sh --bootstrap-only

fmt:
	stylua nvim

install-macos:
	bash bin/new_macos.sh

install-debian:
	bash bin/new_debian.sh

install-centos:
	bash bin/new_centos.sh
