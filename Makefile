.PHONY: all install
all: install
install:
	gksu ' \
		install -C -o root -g root -m 755 find_dupl.pl /usr/bin \
	'
