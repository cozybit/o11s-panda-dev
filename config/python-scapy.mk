#############################################################
#
# python-scapy
#
#############################################################

PYTHON_SCAPY_VERSION         = @SCAPY_VERSION@
PYTHON_SCAPY_SOURCE          = $(PYTHON_SCAPY_VERSION).tar.gz
PYTHON_SCAPY_SITE            = @SCAPY_URL@
PYTHON_SCAPY_INSTALL_STAGING = YES
PYTHON_SCAPY_DEPENDENCIES    = python

define PYTHON_SCAPY_BUILD_CMDS
	(cd $(@D);                                              \
	 CC="$(TARGET_CC)"                                      \
	 CFLAGS="$(TARGET_CFLAGS)"                              \
	 LDSHARED="$(TARGET_CROSS)gcc -shared"                  \
	 CROSS_COMPILING=yes                                    \
	 _python_sysroot=$(STAGING_DIR)                         \
	 _python_srcdir=$(BUILD_DIR)/python$(PYTHON_VERSION)    \
	 _python_prefix=/usr                                    \
	 _python_exec_prefix=/usr                               \
	 $(HOST_DIR)/usr/bin/python setup.py build              \
	)
endef

# Shamelessly vampirised from python-pygame ;-)
define PYTHON_SCAPY_INSTALL_TARGET_CMDS
	(cd $(@D);                                              \
	 $(HOST_DIR)/usr/bin/python setup.py install            \
	                            --prefix=$(TARGET_DIR)/usr  \
	)
endef

$(eval $(generic-package))
