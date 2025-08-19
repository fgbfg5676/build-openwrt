#!/bin/bash
#
# 最终解决方案脚本 v56 - 修复net-snmp路径问题
# 作者: The Architect & Manus AI
#

set -e

# -------------------- 日志函数 --------------------
log_info() { echo -e "[$(date +'%H:%M:%S')] \033[34mℹ️  $*\033[0m"; }
log_error() { echo -e "[$(date +'%H:%M:%S')] \033[31m❌ $*\033[0m"; exit 1; }
log_success() { echo -e "[$(date +'%H:%M:%S')] \033[32m✅ $*\033[0m"; }

log_info "===== 开始执行预编译配置 ====="

# -------------------- 步骤 1：基础变量定义 --------------------
log_info "步骤 1：定义基础变量..."
DTS_DIR="target/linux/ipq40xx/files/arch/arm/boot/dts"
DTS_FILE="$DTS_DIR/qcom-ipq4019-cm520-79f.dts"
GENERIC_MK="target/linux/ipq40xx/image/generic.mk"
CUSTOM_PLUGINS_DIR="package/custom"

# 尝试多种可能的net-snmp路径（兼容不同OpenWrt版本）
POSSIBLE_SNMP_PATHS=(
    "package/feeds/packages/net-snmp"
    "package/network/services/net-snmp"
    "feeds/packages/net-snmp"
)

# 自动检测net-snmp目录
SNMP_DIR=""
for path in "${POSSIBLE_SNMP_PATHS[@]}"; do
    if [ -d "$path" ]; then
        SNMP_DIR="$path"
        break
    fi
done

if [ -z "$SNMP_DIR" ]; then
    log_info "未找到net-snmp包，跳过冲突修复（将在配置中直接禁用）"
    SNMP_NOT_FOUND=1
else
    SNMP_MAKEFILE="$SNMP_DIR/Makefile"
    # 处理不同版本的配置文件命名差异
    if [ -f "$SNMP_DIR/Config.in" ]; then
        SNMP_CONFIG="$SNMP_DIR/Config.in"
    elif [ -f "$SNMP_DIR/config.in" ]; then
        SNMP_CONFIG="$SNMP_DIR/config.in"
    else
        log_info "未找到net-snmp配置文件，使用备选方案"
        SNMP_CONFIG_NOT_FOUND=1
    fi
fi

log_success "基础变量定义完成。"

# -------------------- 步骤 2：创建必要的目录 --------------------
log_info "步骤 2：创建必要的目录..."
mkdir -p "$DTS_DIR" "$CUSTOM_PLUGINS_DIR"
log_success "目录创建完成。"

# -------------------- 步骤 3：写入DTS文件 --------------------
log_info "步骤 3：正在写入DTS文件..."
cat > "$DTS_FILE" <<'EOF'
/dts-v1/;
// SPDX-License-Identifier: GPL-2.0-or-later OR MIT

#include "qcom-ipq4019.dtsi"
#include <dt-bindings/gpio/gpio.h>
#include <dt-bindings/input/input.h>
#include <dt-bindings/soc/qcom,tcsr.h>

/ {
	model = "MobiPromo CM520-79F";
	compatible = "mobipromo,cm520-79f";

	aliases {
		led-boot = &led_sys;
		led-failsafe = &led_sys;
		led-running = &led_sys;
		led-upgrade = &led_sys;
	};

	chosen {
		bootargs-append = " ubi.block=0,1 root=/dev/ubiblock0_1";
	};

	soc {
		rng@22000 { status = "okay"; };
		mdio@90000 {
			status = "okay";
			pinctrl-0 = <&mdio_pins>;
			pinctrl-names = "default";
			reset-gpios = <&tlmm 47 GPIO_ACTIVE_LOW>;
			reset-delay-us = <1000>;
		};
		ess-psgmii@98000 { status = "okay"; };
		tcsr@1949000 {
			compatible = "qcom,tcsr";
			reg = <0x1949000 0x100>;
			qcom,wifi_glb_cfg = <TCSR_WIFI_GLB_CFG>;
		};
		tcsr@194b000 {
			compatible = "qcom,tcsr";
			reg = <0x194b000 0x100>;
			qcom,usb-hsphy-mode-select = <TCSR_USB_HSPHY_HOST_MODE>;
		};
		ess_tcsr@1953000 {
			compatible = "qcom,tcsr";
			reg = <0x1953000 0x1000>;
			qcom,ess-interface-select = <TCSR_ESS_PSGMII>;
		};
		tcsr@1957000 {
			compatible = "qcom,tcsr";
			reg = <0x1957000 0x100>;
			qcom,wifi_noc_memtype_m0_m2 = <TCSR_WIFI_NOC_MEMTYPE_M0_M2>;
		};
		usb2@60f8800 {
			status = "okay";
			dwc3@6000000 {
				#address-cells = <1>;
				#size-cells = <0>;
				usb2_port1: port@1 {
					reg = <1>;
					#trigger-source-cells = <0>;
				};
			};
		};
		usb3@8af8800 {
			status = "okay";
			dwc3@8a00000 {
				#address-cells = <1>;
				#size-cells = <0>;
				usb3_port1: port@1 {
					reg = <1>;
					#trigger-source-cells = <0>;
				};
				usb3_port2: port@2 {
					reg = <2>;
					#trigger-source-cells = <0>;
				};
			};
		};
		crypto@8e3a000 { status = "okay"; };
		watchdog@b017000 { status = "okay"; };
		ess-switch@c000000 { status = "okay"; };
		edma@c080000 { status = "okay"; };
	};

	led_spi {
		compatible = "spi-gpio";
		#address-cells = <1>;
		#size-cells = <0>;
		sck-gpios = <&tlmm 40 GPIO_ACTIVE_HIGH>;
		mosi-gpios = <&tlmm 36 GPIO_ACTIVE_HIGH>;
		num-chipselects = <0>;
		led_gpio: led_gpio@0 {
			compatible = "fairchild,74hc595";
			reg = <0>;
			gpio-controller;
			#gpio-cells = <2>;
			registers-number = <1>;
			spi-max-frequency = <1000000>;
		};
	};

	leds {
		compatible = "gpio-leds";
		usb {
			label = "blue:usb";
			gpios = <&tlmm 10 GPIO_ACTIVE_HIGH>;
			linux,default-trigger = "usbport";
			trigger-sources = <&usb3_port1>, <&usb3_port2>, <&usb2_port1>;
		};
		led_sys: can {
			label = "blue:can";
			gpios = <&tlmm 11 GPIO_ACTIVE_HIGH>;
		};
		wan { label = "blue:wan"; gpios = <&led_gpio 0 GPIO_ACTIVE_LOW>; };
		lan1 { label = "blue:lan1"; gpios = <&led_gpio 1 GPIO_ACTIVE_LOW>; };
		lan2 { label = "blue:lan2"; gpios = <&led_gpio 2 GPIO_ACTIVE_LOW>; };
		wlan2g {
			label = "blue:wlan2g";
			gpios = <&led_gpio 5 GPIO_ACTIVE_LOW>;
			linux,default-trigger = "phy0tpt";
		};
		wlan5g {
			label = "blue:wlan5g";
			gpios = <&led_gpio 6 GPIO_ACTIVE_LOW>;
			linux,default-trigger = "phy1tpt";
		};
	};

	keys {
		compatible = "gpio-keys";
		reset {
			label = "reset";
			gpios = <&tlmm 18 GPIO_ACTIVE_LOW>;
			linux,code = <KEY_RESTART>;
		};
	};
};

&blsp_dma { status = "okay"; };
&blsp1_uart1 { status = "okay"; };
&blsp1_uart2 { status = "okay"; };
&cryptobam { status = "okay"; };

&gmac0 {
	status = "okay";
	nvmem-cells = <&macaddr_art_1006>;
	nvmem-cell-names = "mac-address";
};

&gmac1 {
	status = "okay";
	nvmem-cells = <&macaddr_art_5006>;
	nvmem-cell-names = "mac-address";
};

&nand {
	pinctrl-0 = <&nand_pins>;
	pinctrl-names = "default";
	status = "okay";
	nand@0 {
		partitions {
			compatible = "fixed-partitions";
			#address-cells = <1>;
			#size-cells = <1>;
			partition@0 {
				label = "Bootloader";
				reg = <0x0 0xb00000>;
				read-only;
			};
			art: partition@b00000 {
				label = "ART";
				reg = <0xb00000 0x80000>;
				read-only;
				compatible = "nvmem-cells";
				#address-cells = <1>;
				#size-cells = <1>;
				precal_art_1000: precal@1000 { reg = <0x1000 0x2f20>; };
				macaddr_art_1006: macaddr@1006 { reg = <0x1006 0x6>; };
				precal_art_5000: precal@5000 { reg = <0x5000 0x2f20>; };
				macaddr_art_5006: macaddr@5006 { reg = <0x5006 0x6>; };
			};
			partition@b80000 {
				label = "rootfs";
				reg = <0xb80000 0x7480000>;
			};
		};
	};
};

&qpic_bam { status = "okay"; };

&tlmm {
	mdio_pins: mdio_pinmux {
		mux_1 { pins = "gpio6"; function = "mdio"; bias-pull-up; };
		mux_2 { pins = "gpio7"; function = "mdc"; bias-pull-up; };
	};
	nand_pins: nand_pins {
		pullups {
			pins = "gpio52", "gpio53", "gpio58", "gpio59";
			function = "qpic";
			bias-pull-up;
		};
		pulldowns {
			pins = "gpio54", "gpio55", "gpio56", "gpio57", "gpio60", "gpio61", "gpio62", "gpio63", "gpio64", "gpio65", "gpio66", "gpio67", "gpio68", "gpio69";
			function = "qpic";
			bias-pull-down;
		};
	};
};

&usb3_ss_phy { status = "okay"; };
&usb3_hs_phy { status = "okay"; };
&usb2_hs_phy { status = "okay"; };
&wifi0 { status = "okay"; nvmem-cell-names = "pre-calibration"; nvmem-cells = <&precal_art_1000>; qcom,ath10k-calibration-variant = "CM520-79F"; };
&wifi1 { status = "okay"; nvmem-cell-names = "pre-calibration"; nvmem-cells = <&precal_art_5000>; qcom,ath10k-calibration-variant = "CM520-79F"; };
EOF
log_success "DTS文件写入成功。"

# -------------------- 步骤 4：创建网络配置文件 --------------------
log_info "步骤 4：创建针对CM520-79F的网络配置文件..."
BOARD_DIR="target/linux/ipq40xx/base-files/etc/board.d"
mkdir -p "$BOARD_DIR"
cat > "$BOARD_DIR/02_network" <<EOF
#!/bin/sh
. /lib/functions/system.sh
ipq40xx_board_detect() {
	local machine
	machine=\$(board_name)
	case "\$machine" in
	"mobipromo,cm520-79f")
		ucidef_set_interfaces_lan_wan "eth1" "eth0"
		;;
	esac
}
boot_hook_add preinit_main ipq40xx_board_detect
EOF
log_success "网络配置文件创建完成。"

# -------------------- 步骤 5：配置设备规则 --------------------
log_info "步骤 5：配置设备规则..."
if ! grep -q "define Device/mobipromo_cm520-79f" "$GENERIC_MK"; then
    cat <<EOF >> "$GENERIC_MK"

define Device/mobipromo_cm520-79f
  DEVICE_VENDOR := MobiPromo
  DEVICE_MODEL := CM520-79F
  DEVICE_DTS := qcom-ipq4019-cm520-79f
  KERNEL_SIZE := 4096k
  ROOTFS_SIZE := 16384k
  IMAGE_SIZE := 81920k
  IMAGE/trx := append-kernel | pad-to \$(KERNEL_SIZE) | append-rootfs | trx -o \$@
endef
TARGET_DEVICES += mobipromo_cm520-79f
EOF
    log_success "设备规则添加完成。"
else
    sed -i 's/IMAGE_SIZE := 32768k/IMAGE_SIZE := 81920k/' "$GENERIC_MK"
    log_info "设备规则已存在，更新IMAGE_SIZE。"
fi

# -------------------- 步骤 6：通用系统设置 --------------------
log_info "步骤 6：修改默认IP、密码和版本信息..."
sed -i 's/192.168.1.1/192.168.5.1/g' package/base-files/files/bin/config_generate
log_success "默认IP修改为192.168.5.1"
sed -i 's/root:::0:99999:7:::/root:$1$V4UetPzk$CYXluq4wUazHjmCDBCqXF.::0:99999:7:::/g' package/base-files/files/etc/shadow
log_success "默认密码设置为'password'"
sed -i "s|DISTRIB_REVISION='.*'|DISTRIB_REVISION='R$(date +%Y.%m.%d)'|g" package/base-files/files/etc/openwrt_release
echo "DISTRIB_SOURCECODE='immortalwrt'" >> package/base-files/files/etc/openwrt_release
log_success "版本号和源代码信息已更新。"

# -------------------- 步骤 7：sirpdboy插件集成(强制更新) --------------------
log_info "步骤 7：集成sirpdboy插件(强制更新)..."
SIRPDBOY_REPO="https://github.com/sirpdboy"
for plugin in luci-app-partexp luci-app-advanced luci-app-poweroffdevice; do
  rm -rf "$CUSTOM_PLUGINS_DIR/$plugin"
  if git clone --depth 1 "$SIRPDBOY_REPO/$plugin" "$CUSTOM_PLUGINS_DIR/$plugin"; then
    log_success "$plugin克隆成功"
  else
    log_error "$plugin克隆失败"
  fi
done

# -------------------- 步骤 8：集成PassWall2(强制更新) --------------------
log_info "步骤 8：集成PassWall2(强制更新)..."
PW2_APP_DIR="$CUSTOM_PLUGINS_DIR/luci-app-passwall"
PW2_PKG_DIR="$CUSTOM_PLUGINS_DIR/passwall-packages"
rm -rf "$PW2_APP_DIR" "$PW2_PKG_DIR"
log_info "已删除旧的PassWall仓库，准备重新克隆..."
if git clone --depth 1 https://github.com/xiaorouji/openwrt-passwall.git "$PW2_APP_DIR"; then
  log_success "PassWall克隆成功"
else
  log_error "PassWall克隆失败"
fi
if git clone --depth 1 https://github.com/xiaorouji/openwrt-passwall-packages.git "$PW2_PKG_DIR"; then
  log_success "PassWall公共依赖克隆成功"
else
  log_error "PassWall公共依赖克隆失败"
fi

# -------------------- 步骤 9：更新与安装Feeds --------------------
log_info "步骤 9：更新和安装所有feeds..."
./scripts/feeds update -a
./scripts/feeds install -a
log_success "Feeds操作完成。"

# -------------------- 步骤 10：修复net-snmp依赖冲突 --------------------
log_info "步骤 10：处理net-snmp依赖问题..."

# 只有找到完整的net-snmp文件结构才进行复杂修复
if [ -z "$SNMP_NOT_FOUND" ] && [ -z "$SNMP_CONFIG_NOT_FOUND" ] && [ -f "$SNMP_MAKEFILE" ] && [ -f "$SNMP_CONFIG" ]; then
    log_info "找到完整net-snmp包，执行二选一修复方案..."
    
    log_info "备份原始配置文件..."
    cp "$SNMP_MAKEFILE" "$SNMP_MAKEFILE.bak" || log_error "备份Makefile失败"
    cp "$SNMP_CONFIG" "$SNMP_CONFIG.bak" || log_error "备份Config.in失败"

    # 修改Makefile依赖规则
    log_info "修改Makefile依赖规则..."
    sed -i '/^define Package\/snmpd-ssl$/,/^endef$/ {
        /^  DEPENDS:=/c\  DEPENDS:=+libnetsnmp-ssl +SNMP_ENABLE_SSL:libopenssl
    }' "$SNMP_MAKEFILE"

    sed -i '/^define Package\/snmpd-nossl$/,/^endef$/ {
        /^  DEPENDS:=/c\  DEPENDS:=+libnetsnmp-nossl +!SNMP_ENABLE_SSL:libopenssl
    }' "$SNMP_MAKEFILE"

    sed -i '/^define Package\/libnetsnmp-ssl$/,/^endef$/ {
        /^  DEPENDS:=/c\  DEPENDS:=+SNMP_ENABLE_SSL:libopenssl +SNMP_ENABLE_SSL:libcrypto
    }' "$SNMP_MAKEFILE"

    sed -i '/^define Package\/libnetsnmp-nossl$/,/^endef$/ {
        /^  DEPENDS:=/c\  DEPENDS:=+!SNMP_ENABLE_SSL:libopenssl +!SNMP_ENABLE_SSL:libcrypto
    }' "$SNMP_MAKEFILE"

    # 修改Config.in配置选项
    log_info "修改Config.in配置选项..."
    sed -i '1i config SNMP_ENABLE_SSL\n    bool "Enable SSL support in net-snmp"\n    default n\n    help\n      Choose whether to build net-snmp with SSL support.\n      If enabled, SSL versions of libraries and tools will be built.\n      If disabled, non-SSL versions will be used.\n' "$SNMP_CONFIG"

    # 设置子包依赖关系
    sed -i '/^config PACKAGE_snmpd-ssl$/,/^endmenu$/ {
        /^    depends on /c\    depends on SNMP_ENABLE_SSL
    }' "$SNMP_CONFIG"

    sed -i '/^config PACKAGE_snmpd-nossl$/,/^endmenu$/ {
        /^    depends on /c\    depends on !SNMP_ENABLE_SSL
    }' "$SNMP_CONFIG"

    sed -i '/^config PACKAGE_libnetsnmp-ssl$/,/^endmenu$/ {
        /^    depends on /c\    depends on SNMP_ENABLE_SSL
    }' "$SNMP_CONFIG"

    sed -i '/^config PACKAGE_libnetsnmp-nossl$/,/^endmenu$/ {
        /^    depends on /c\    depends on !SNMP_ENABLE_SSL
    }' "$SNMP_CONFIG"

    log_success "net-snmp依赖冲突修复完成"
    SNMP_FIXED=1
else
    log_info "未找到完整的net-snmp配置文件，使用简化方案：直接禁用冲突包"
    SNMP_FIXED=0
fi

# -------------------- 步骤 11：生成最终配置文件 --------------------
log_info "步骤 11：生成最终配置文件..."
CONFIG_FILE=".config.custom"
rm -f "$CONFIG_FILE"

# 启用sirpdboy插件
echo "CONFIG_PACKAGE_luci-app-partexp=y" >> "$CONFIG_FILE"
echo "CONFIG_PACKAGE_luci-app-advanced=y" >> "$CONFIG_FILE"
echo "CONFIG_PACKAGE_luci-app-poweroffdevice=y" >> "$CONFIG_FILE"

# 启用PassWall2并切换到Shadowsocks-Rust核心
echo "CONFIG_PACKAGE_luci-app-passwall=y" >> "$CONFIG_FILE"
echo "CONFIG_PACKAGE_luci-app-passwall_INCLUDE_Shadowsocks_Rust_Client=y" >> "$CONFIG_FILE"
echo "# CONFIG_PACKAGE_luci-app-passwall_INCLUDE_Shadowsocks_Libev_Client is not set" >> "$CONFIG_FILE"

# 配置net-snmp（根据不同情况处理）
if [ "$SNMP_FIXED" = "1" ]; then
    # 如果已修复，配置为nossl版本
    echo "CONFIG_SNMP_ENABLE_SSL=n" >> "$CONFIG_FILE"
    echo "CONFIG_PACKAGE_libnetsnmp-nossl=y" >> "$CONFIG_FILE"
    echo "CONFIG_PACKAGE_snmpd-nossl=y" >> "$CONFIG_FILE"
    echo "# CONFIG_PACKAGE_libnetsnmp-ssl is not set" >> "$CONFIG_FILE"
    echo "# CONFIG_PACKAGE_snmpd-ssl is not set" >> "$CONFIG_FILE"
else
    # 如果未找到或无法修复，直接禁用所有net-snmp相关包
    echo "# 禁用所有net-snmp包以避免冲突" >> "$CONFIG_FILE"
    echo "# CONFIG_PACKAGE_net-snmp is not set" >> "$CONFIG_FILE"
    echo "# CONFIG_PACKAGE_snmpd is not set" >> "$CONFIG_FILE"
    echo "# CONFIG_PACKAGE_libnetsnmp is not set" >> "$CONFIG_FILE"
    echo "# CONFIG_PACKAGE_snmp-utils is not set" >> "$CONFIG_FILE"
    echo "# CONFIG_PACKAGE_libnetsnmp-ssl is not set" >> "$CONFIG_FILE"
    echo "# CONFIG_PACKAGE_libnetsnmp-nossl is not set" >> "$CONFIG_FILE"
    echo "# CONFIG_PACKAGE_snmpd-ssl is not set" >> "$CONFIG_FILE"
    echo "# CONFIG_PACKAGE_snmpd-nossl is not set" >> "$CONFIG_FILE"
fi

# 启用其他基础依赖
echo "CONFIG_PACKAGE_kmod-ubi=y" >> "$CONFIG_FILE"
echo "CONFIG_PACKAGE_kmod-ubifs=y" >> "$CONFIG_FILE"
echo "CONFIG_PACKAGE_trx=y" >> "$CONFIG_FILE"
echo "CONFIG_PACKAGE_kmod-ath10k-ct=y" >> "$CONFIG_FILE"
echo "CONFIG_PACKAGE_ath10k-firmware-qca4019-ct=y" >> "$CONFIG_FILE"
echo "CONFIG_PACKAGE_ipq-wifi-mobipromo_cm520-79f=y" >> "$CONFIG_FILE"
echo "CONFIG_PACKAGE_dnsmasq_full_dhcpv6=y" >> "$CONFIG_FILE"
echo "CONFIG_TARGET_ROOTFS_NO_CHECK_SIZE=y" >> "$CONFIG_FILE"

# 合并配置并生成最终配置
cat "$CONFIG_FILE" >> .config
rm -f "$CONFIG_FILE"

make defconfig
log_success "最终配置文件生成完成。"

log_success "所有预编译步骤均已成功完成！准备开始编译..."
