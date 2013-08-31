#############################################################
#
# trace-cmd
#
#############################################################

TRACE_CMD_VERSION         = master
TRACE_CMD_SITE            = git://git.kernel.org/pub/scm/linux/kernel/git/rostedt/trace-cmd.git
TRACE_CMD_INSTALL_STAGING = YES

define TRACE_CMD_BUILD_CMDS
	(cd $(@D);                                              \
	 CC="$(TARGET_CC)"                                      \
	 CFLAGS="$(TARGET_CFLAGS) -I$(STAGING_DIR)/usr/include/python$(PYTHON_VERSION_MAJOR)" \
	 LDSHARED="$(TARGET_CROSS)gcc -shared"                  \
	 CROSS_COMPILING=yes                                    \
	 make NO_PYTHON=1 \
	)
endef
 
define TRACE_CMD_INSTALL_TARGET_CMDS
	(cd $(@D);                                              \
	 make DESTDIR=$(TARGET_DIR) \
		NO_PYTHON=1 \
		install  \
	)
endef

define TRACE_CMD_UNINSTALL_TARGET_CMDS
	rm -f $(TARGET_DIR)/usr/local/bin/trace-cmd
	rm -rf $(TARGET_DIR)/usr/local/lib/trace-cmd
endef

define TRACE_CMD_CLEAN_CMDS
	-$(MAKE) -C $(@D) clean
endef

$(eval $(generic-package))
