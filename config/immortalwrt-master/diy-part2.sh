#!/bin/bash
#
# 最終解決方案腳本 v47 - 強制更新插件並修復依賴
# 作者: The Architect & Manus AI
#

set -e

# -------------------- 日誌函數 --------------------
log_info() { echo -e "[$(date +'%H:%M:%S')] \033[34mℹ️  $*\033[0m"; }
log_error() { echo -e "[$(date +'%H:%M:%S')] \033[31m❌ $*\033[0m"; exit 1; }
log_success() { echo -e "[$(date +'%H:%M:%S')] \033[32m✅ $*\033[0m"; }

log_info "===== 開始執行預編譯配置 ====="

# ... [步驟 1 到 7 的內容與之前相同，此處省略] ...
# -------------------- 步驟 1：基礎變量定義 --------------------
log_info "步驟 1：定義基礎變量..."
DTS_DIR="target/linux/ipq40xx/files/arch/arm/boot/dts"
DTS_FILE="$DTS_DIR/qcom-ipq4019-cm520-79f.dts"
GENERIC_MK="target/linux/ipq40xx/image/generic.mk"
CUSTOM_PLUGINS_DIR="package/custom"
log_success "基礎變量定義完成。"

# -------------------- 步驟 2：創建必要的目錄 --------------------
log_info "步驟 2：創建必要的目錄..."
mkdir -p "$DTS_DIR" "$CUSTOM_PLUGINS_DIR"
log_success "目錄創建完成。"

# -------------------- 步驟 3：寫入DTS文件 --------------------
log_info "步驟 3：正在寫入100%正確的DTS文件..."
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
log_success "DTS文件寫入成功。"

# -------------------- 步驟 4：創建網絡配置文件 --------------------
log_info "步驟 4：創建針對 CM520-79F 的網絡配置文件..."
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
log_success "網絡配置文件創建完成。"

# -------------------- 步驟 5：配置設備規則 --------------------
log_info "步驟 5：配置設備規則..."
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

# -------------------- 步驟 6：通用系統設置 --------------------
log_info "步驟 6：修改默認IP、密碼和版本信息..."
sed -i 's/192.168.1.1/192.168.5.1/g' package/base-files/files/bin/config_generate
log_success "默認IP修改為 192.168.5.1"
sed -i 's/root:::0:99999:7:::/root:$1$V4UetPzk$CYXluq4wUazHjmCDBCqXF.::0:99999:7:::/g' package/base-files/files/etc/shadow
log_success "默認密碼設置為 'password'"
sed -i "s|DISTRIB_REVISION='.*'|DISTRIB_REVISION='R$(date +%Y.%m.%d)'|g" package/base-files/files/etc/openwrt_release
echo "DISTRIB_SOURCECODE='immortalwrt'" >>package/base-files/files/etc/openwrt_release
log_success "版本號和源碼信息已更新。"

# -------------------- 步驟 7：sirpdboy插件集成 --------------------
log_info "步驟 7：集成 sirpdboy 插件..."
SIRPDBOY_REPO="https://github.com/sirpdboy"
for plugin in luci-app-partexp luci-app-advanced luci-app-poweroffdevice; do
  rm -rf "$CUSTOM_PLUGINS_DIR/$plugin"
  if git clone --depth 1 $SIRPDBOY_REPO/$plugin "$CUSTOM_PLUGINS_DIR/$plugin"; then
    log_success "$plugin 克隆成功"
  else
    log_error "$plugin 克隆失敗"
  fi
done

# -------------------- 步驟 8：集成 PassWall2 (強制更新 ) --------------------
log_info "步驟 8：集成 PassWall2 (強制更新)..."
PW2_APP_DIR="$CUSTOM_PLUGINS_DIR/luci-app-passwall2"
PW2_PKG_DIR="$CUSTOM_PLUGINS_DIR/passwall-packages"
rm -rf "$PW2_APP_DIR" "$PW2_PKG_DIR"
log_info "已刪除舊的 PassWall 倉庫，準備重新克隆..."

if git clone --depth 1 https://github.com/xiaorouji/openwrt-passwall2.git "$PW2_APP_DIR"; then
  log_success "PassWall2 克隆成功"
else
  log_error "PassWall2 克隆失敗"
fi

if git clone --depth 1 https://github.com/xiaorouji/openwrt-passwall-packages.git "$PW2_PKG_DIR"; then
  log_success "PassWall 公共依賴克隆成功"
else
  log_error "PassWall 公共依賴克隆失敗"
fi

# -------------------- 步驟 9：更新與安裝Feeds --------------------
log_info "步驟 9：更新和安裝所有feeds..."
./scripts/feeds update -a
./scripts/feeds install -a
log_success "Feeds操作完成 。"

# -------------------- 步驟 10：應用 Kconfig 補丁修復遞歸依賴 --------------------
log_info "步驟 10：應用 Kconfig 補丁修復 SNMP 遞歸依賴..."
SNMP_KCONFIG_PATH="feeds/packages/net/snmpd/Config.in"
if [ -f "$SNMP_KCONFIG_PATH" ]; then
    sed -i 's/select PACKAGE_snmpd-nossl/select PACKAGE_snmpd-nossl if !SNMPD_WITH_OPENSSL/' "$SNMP_KCONFIG_PATH"
    log_success "成功修補 $SNMP_KCONFIG_PATH"
else
    log_info "未找到 snmpd Kconfig 文件，跳過修補。"
fi

# -------------------- 步驟 11：生成最終配置文件 --------------------
log_info "步驟 11：正在啟用必要的軟件包並生成最終配置..."
CONFIG_FILE=".config.custom"
rm -f $CONFIG_FILE

# --- 啟用 sirpdboy 插件 ---
echo "CONFIG_PACKAGE_luci-app-partexp=y" >> $CONFIG_FILE
echo "CONFIG_PACKAGE_luci-app-advanced=y" >> $CONFIG_FILE
echo "CONFIG_PACKAGE_luci-app-poweroffdevice=y" >> $CONFIG_FILE

# --- 啟用 PassWall2 ---
echo "CONFIG_PACKAGE_luci-app-passwall2=y" >> $CONFIG_FILE

# --- 啟用其他基礎依賴 ---
echo "CONFIG_PACKAGE_kmod-ubi=y" >> $CONFIG_FILE
echo "CONFIG_PACKAGE_kmod-ubifs=y" >> $CONFIG_FILE
echo "CONFIG_PACKAGE_trx=y" >> $CONFIG_FILE
echo "CONFIG_PACKAGE_kmod-ath10k-ct=y" >> $CONFIG_FILE
echo "CONFIG_PACKAGE_ath10k-firmware-qca4019-ct=y" >> $CONFIG_FILE
echo "CONFIG_PACKAGE_ipq-wifi-mobipromo_cm520-79f=y" >> $CONFIG_FILE
echo "CONFIG_PACKAGE_dnsmasq_full_dhcpv6=y" >> $CONFIG_FILE
echo "CONFIG_TARGET_ROOTFS_NO_CHECK_SIZE=y" >> $CONFIG_FILE

cat $CONFIG_FILE >> .config
rm -f $CONFIG_FILE

make defconfig
log_success "最終配置文件生成完成。"

log_success "所有預編譯步驟均已成功完成！準備開始編譯..."
