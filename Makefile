.PHONY: help check check-whiteboard check-smoke setup setup-dry-run setup-links setup-bootstrap doctor fmt install-macos install-debian install-centos

help:
	@echo "Machine setup:"
	@echo "  make install-macos   - Install/upgrade macOS tooling"
	@echo "  make install-debian  - Install Debian/Ubuntu tooling"
	@echo "  make install-centos  - Install CentOS tooling"
	@echo "  make setup           - Symlink configs and clone shell/tmux deps (idempotent; also run after git pull)"
	@echo "  make setup-dry-run   - Preview what setup would change"
	@echo "  make setup-links     - Setup subset: symlink/copy configs only"
	@echo "  make setup-bootstrap - Setup subset: clone shell/tmux deps only"
	@echo "  make doctor          - Report dotfile link/tool status"
	@echo ""
	@echo "Repo development:"
	@echo "  make check           - Static repo checks: syntax/lint/format (fast; run locally before pushing)"
	@echo "  make check-whiteboard - Whiteboard security regressions (Python 3, Node.js, Bash)"
	@echo "  make check-smoke     - check + boot Neovim headless with plugins (slow; what CI runs)"
	@echo "  make fmt             - Format Neovim Lua config with stylua"
	@echo ""
	@echo "Sync this machine after a PR merged elsewhere:"
	@echo "  git pull && make setup   (links are live on pull; setup adds any new links/clones)"
	@echo "  then reload affected apps: tmux prefix+r, restart nvim"

install-macos:
	bash bin/new_macos.sh

install-debian:
	bash bin/new_debian.sh

install-centos:
	bash bin/new_centos.sh

setup:
	bash bin/quick_setup.sh

setup-dry-run:
	bash bin/quick_setup.sh --dry-run

setup-links:
	bash bin/quick_setup.sh --links-only

setup-bootstrap:
	bash bin/quick_setup.sh --bootstrap-only

doctor:
	bash bin/quick_setup.sh --doctor

check:
	bash bin/check.sh

check-whiteboard:
	python3 -B -m unittest discover -s pi/agent/skills/whiteboard -p 'test_*.py' -v

check-smoke:
	RUN_NVIM_SMOKE=1 bash bin/check.sh

fmt:
	stylua nvim
