# Copyright (C) 2009, Parrot Foundation.

# Command aliases
PERL        := /usr/bin/perl
RM_F        := $(PERL) -MExtUtils::Command -e rm_f

O           := .o
EXE         :=

PARROT_ROOT := $(HOME)/git/rakudo/parrot_install
PARROT_BIN  := $(PARROT_ROOT)/bin
PARROT_LIB  := $(PARROT_ROOT)/lib/1.5.0-devel

PARROT      := $(PARROT_BIN)/parrot
PBC_TO_EXE  := $(PARROT_BIN)/pbc_to_exe
NQP_PBC     := $(PARROT_LIB)/languages/nqp/nqp.pbc

# The default target
all: plumage

# List all user-visible targest
help:
	@echo ""
	@echo "The following targets are available:"
	@echo ""
	@echo "  all:         Generate plumage executable (default target)"
	@echo "  clean:       Clean generated files"
	@echo "  help:        Print this help message"
	@echo ""

plumage: plumage.pbc
	$(PBC_TO_EXE) plumage.pbc

plumage.pbc: plumage.pir
	$(PARROT) -o plumage.pbc plumage.pir

plumage.pir: plumage.nqp
	$(PARROT) $(NQP_PBC) --target=pir -o plumage.pir plumage.nqp

# Convenience
realclean: clean

clean:
	$(RM_F) "*~" "*.pbc" "*$(O)" "*.c" plumage.pir plumage$(EXE)

# Local variables:
#   mode: makefile
# End:
# vim: ft=make:
