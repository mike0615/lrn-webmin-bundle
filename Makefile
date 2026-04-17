NAME    := lrn-webmin-bundle
VERSION := 1.0
RELEASE := 1
EL_VER  ?= 9
TARBALL := SOURCES/$(NAME)-$(VERSION).tar.gz
SPECFILE := SPECS/$(NAME).spec

.PHONY: all rpm tarball clean deps info fetch-deps

all: rpm

info:
	@echo "Name:    $(NAME)"
	@echo "Version: $(VERSION)-$(RELEASE)"
	@echo "EL_VER:  $(EL_VER)"
	@echo "Tarball: $(TARBALL)"

deps:
	@echo "[*] Installing build dependencies..."
	dnf install -y rpm-build git curl createrepo_c perl

tarball: $(TARBALL)

$(TARBALL):
	@echo "[*] Creating source tarball..."
	@mkdir -p SOURCES
	tar czf $(TARBALL) \
		--transform 's|^src|$(NAME)-$(VERSION)|' \
		src/
	@echo "[+] Tarball: $(TARBALL)"

rpm: tarball
	@echo "[*] Building RPM for EL$(EL_VER)..."
	rpmbuild -bb \
		--define "_topdir $(CURDIR)" \
		--define "_version $(VERSION)" \
		--define "_release $(RELEASE)" \
		--define "dist .el$(EL_VER)" \
		--define "_el_ver $(EL_VER)" \
		--define "_repo_dir $(CURDIR)/SOURCES/repo-el$(EL_VER)" \
		$(SPECFILE)
	@echo "[+] RPM built:"
	@find RPMS/ -name '*.rpm' -print

fetch-deps:
	@echo "[*] Fetching dependencies for EL$(EL_VER) (requires internet)..."
	EL_VER=$(EL_VER) ./scripts/fetch-deps.sh

clean:
	rm -rf BUILD/* RPMS/* SRPMS/* $(TARBALL)
	@echo "[+] Clean complete"

distclean: clean
	rm -rf SOURCES/repo-el*/
	@echo "[+] Dist-clean complete"
