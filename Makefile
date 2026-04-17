NAME    := lrn-webmin-bundle
VERSION := 1.0
RELEASE := 1
TARBALL := SOURCES/$(NAME)-$(VERSION).tar.gz
SPECFILE := SPECS/$(NAME).spec

.PHONY: all rpm tarball clean deps info

all: rpm

info:
	@echo "Name:    $(NAME)"
	@echo "Version: $(VERSION)-$(RELEASE)"
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
	@echo "[*] Building RPM..."
	rpmbuild -bb \
		--define "_topdir $(CURDIR)" \
		--define "_version $(VERSION)" \
		--define "_release $(RELEASE)" \
		$(SPECFILE)
	@echo "[+] RPM built:"
	@find RPMS/ -name '*.rpm' -print

fetch-deps:
	@echo "[*] Fetching dependencies (requires internet)..."
	./scripts/fetch-deps.sh

clean:
	rm -rf BUILD/* RPMS/* SRPMS/* $(TARBALL)
	@echo "[+] Clean complete"

distclean: clean
	rm -rf SOURCES/repo/
	@echo "[+] Dist-clean complete"
