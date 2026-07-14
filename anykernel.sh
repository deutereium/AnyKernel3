# AnyKernel3 Ramdisk Mod Script
# osm0sis @ xda-developers

properties() { '
kernel.string=\\ RE404 Kernel by Project 113 @deutereum @sk113r \\
do.modules=0
do.systemless=1
'; }

devicecheck() {
  local device devicename match product testname vendordevice vendorproduct;
  device=$(getprop ro.product.device 2>/dev/null);
  product=$(getprop ro.build.product 2>/dev/null);
  vendordevice=$(getprop ro.product.vendor.device 2>/dev/null);
  vendorproduct=$(getprop ro.vendor.product.device 2>/dev/null);
  for testname in $(grep 'devicename' anykernel.sh | cut -d= -f2-); do
    for devicename in $device $product $vendordevice $vendorproduct; do
      if [[ "$devicename" == *"$testname"* ]]; then
        match=1
        break
      fi
    done
  done
}

select_option() {
  ui_print " - $1 :"
  ui_print "  (Vol +) $2"
  ui_print "  (Vol -) $3"

  SELECT_RESULT=""
  while true; do
    key_event=$(getevent -qlc 1)
    case "$key_event" in
      *"KEY_VOLUMEUP"*"DOWN"*|*"KEY_VOLUMEUP"*"1"*)
        ui_print "  Selected : $2" " "
        SELECT_RESULT="$2"
        break
        ;;
      *"KEY_VOLUMEDOWN"*"DOWN"*|*"KEY_VOLUMEDOWN"*"1"*)
        ui_print "  Selected : $3" " "
        SELECT_RESULT="$3"
        break
        ;;
    esac
    sleep 0.1
  done
  echo "$SELECT_RESULT"
}

configure_manual() {

  select_option "DTBO Type" "OEM (MIUI/Oxygen)" "AOSP"
  rom_sel="$SELECT_RESULT"
  case "$rom_sel" in
    *miui*|*MIUI*)
      dtbo="dtbo_oem"
      ;;
    *aosp*|*AOSP*)
      dtbo="dtbo_def"
      ;;
  esac

  select_option "IR Blaster" "IR0 (works for most roms)" "IR1 (for newer roms)"
  ir_sel="$SELECT_RESULT"
  case "$ir_sel" in
   *IR0*) ir="ir0" ;;
   *) ir="ir1" ;;
  esac

  select_option "Refresh Rate" "120Hz" "130Hz"
  ref_sel="$SELECT_RESULT"
  case "$ref_sel" in
    *120*|*120Hz*)
      rr="dtbo_120"
      ;;
    *130*|*130Hz*)
      rr="dtbo_130"
      ;;
  esac

  select_option "Lyb Touchscreen mod" "Disable" "Enable"
  tsmod_sel="$SELECT_RESULT"
  case "$tsmod_sel" in
   *Disable*) lyb="lyb0" ;;
   *) lyb="lyb1" ;;
  esac

  if [[ "$lyb" == "lyb1" ]]; then
    select_option "Lyb Touchscreen mode" "Standard (only load Lyb's custom ts firmware)" "Advanced Pressure"
    lyb_sel="$SELECT_RESULT"
    case "$lyb_sel" in
      *Standard*) lyb="lyb1" ;;
      *) lyb="lyb2" ;;
    esac
  else
    lyb="lyb0"
  fi

  select_option "DTB CPU Frequency" "EFFCPU" "Default"
  dtb_sel="$SELECT_RESULT"
  case "$dtb_sel" in
    *EFFCPU*) dtb="dtb_effcpu" ;;
    *) dtb="dtb_def" ;;
  esac

  ui_print " Manual configuration done !" " "
  sleep 0.5
}

configure_auto() {
  sleep 0.1
  miprops="$(file_getprop /vendor/build.prop "ro.vendor.miui.build.region" 2>/dev/null)"
  if [[ -z "$miprops" ]]; then
    miprops="$(file_getprop /product/etc/build.prop "ro.miui.build.region" 2>/dev/null)"
  fi

  oosbrand="$(file_getprop /system/build.prop "ro.product.brand" 2>/dev/null)"
  if [[ -z "$oosbrand" ]]; then
    oosbrand="$(file_getprop /odm/build.prop "ro.product.brand" 2>/dev/null)"
  fi

  case "$miprops" in
    cn|in|ru|id|eu|tr|tw|gb|global|mx|jp|kr|lm|cl|mi)
      ui_print "--> Miui/HyperOS ROM detected, configuring..."
      dtbo="dtbo_oem"
      ;;
    *)
      if echo "$oosbrand" | grep -qi "oneplus"; then
        ui_print "--> OxygenOS ROM detected, configuring..."
        dtbo="dtbo_oem"
      elif [[ "$oplus" != "1" ]]; then
        ui_print "--> AOSP/CLO ROM detected, configuring..."
        dtbo="dtbo_def"
      fi
      ;;
  esac
  sleep 0.1
    ui_print "--> 120hz by default, configuring..."
    rr="dtbo_120"
  sleep 0.1
  if [[ "$ZIPFILE" == *effcpu* || "$ZIPFILE" == *EFFCPU* ]]; then
    ui_print "--> EFFCPUFreq is detected, configuring..."
    dtb="dtb_effcpu"
  else
    ui_print "--> EFFCPUFreq not detected, skipping..."
    dtb="dtb_def"
  fi
  sleep 0.1
    ui_print "--> Lyb tsmod disabled by default (stock MIUI firmware)...."
    lyb="lyb0"
  sleep 0.1
    ui_print "--> using ir0 remote configuration"
    ir="ir0"

  ui_print " " " Auto configuration done !" " "
  sleep 0.1
}

choose_config_mode() {
  ui_print "--> Select Kernel Configuration :"
  ui_print "  (Vol +) Manual Configuration "
  ui_print "  (Vol -) Auto Configuration "
  ui_print "  ! Timeout in 8 seconds, defaults to Auto"

  local timeout=8
  local start now key_event

  start=$(date +%s)

  while :; do
    key_event=$(timeout 0.2 getevent -qlc 1 2>/dev/null)

    if [ -n "$key_event" ]; then
      if echo "$key_event" | grep -q "KEY_VOLUMEUP"; then
        ui_print "  Selected : Manual Configuration" " "
        configure_manual
        return 0
      fi

      if echo "$key_event" | grep -q "KEY_VOLUMEDOWN"; then
        ui_print "  Selected : Auto Configuration" " "
        configure_auto
        return 0
      fi
    fi

    now=$(date +%s)
    if [ $((now - start)) -ge $timeout ]; then
      ui_print "  ! Timeout reached" " "
      configure_auto
      return 0
    fi
  done
}

#
# Install begins here
# 

devicename=vaybpf
case "$devicename" in
  munch|alioth|pipa)
    is_slot_device=1;
  ;;
  apollo|lmi)
    is_slot_device=0;
  ;;
esac
block=/dev/block/bootdevice/by-name/boot
ramdisk_compression=auto
patch_vbmeta_flag=auto

. tools/ak3-core.sh

devicecheck

mv *-Image $home/Image
mv *-dtb $home/dtb
mv *-dtbo.img $home/dtbo.img

dump_boot

if [ -f "$split_img/cmdline.txt" ]; then
  existing_args=$(grep -o 'e404_args=[^ ]*' $split_img/cmdline.txt 2>/dev/null)
else
  existing_args=$(grep "^cmdline=" $split_img/header 2>/dev/null | cut -d= -f2- | grep -o 'e404_args=[^ ]*')
fi

sleep 0.5
if [[ "$SIDELOAD" == "1" ]]; then
  ui_print " " " ! Sideloading Detected, Overriding to Manual Configuration !"
  configure_manual
elif [[ -n "$existing_args" ]]; then
  ui_print "--> Existing cmdline config found : " " "
  ui_print "--> $existing_args" " "
  ui_print "--> Autoconfig will use existing cmdline."
  ui_print "  (Vol +) keep existing"
  ui_print "  (Vol -) Reconfigure"
  ui_print ""
  ui_print "  ! Timeout in 3 seconds, defaults to keep existing"
  key_event=$(timeout 3 sh -c 'while true; do e=$(getevent -qlc 1 2>/dev/null); [ -n "$e" ] && echo "$e" && break; done')
  if echo "$key_event" | grep -q "KEY_VOLUMEDOWN"; then
    ui_print "  Selected : Reconfigure" " "
    sleep 0.5
    choose_config_mode
  else
    ui_print "  Selected : keep existing config" " "
    skip_patch_cmdline=1
  fi
else
  choose_config_mode
fi

ui_print "--> Applying configuration..."

if [[ "$skip_patch_cmdline" != "1" ]]; then
  ui_print " $dtbo,$dtb,$rr,$lyb,$ir"
  patch_cmdline "e404_args" "e404_args=$dtbo,$dtb,$rr,$lyb,$ir"
else
  ui_print " $existing_args"
fi

write_boot

if [[ $is_slot_device == 1 ]]; then
 ui_print "--> Installing to vendor_boot partition... "
  block=/dev/block/bootdevice/by-name/vendor_boot
  ramdisk_compression=auto
  patch_vbmeta_flag=auto
  reset_ak
  dump_boot
  write_boot
else
  ui_print "--> Installing to boot partition... "
fi

if [[ ! -f /vendor/etc/task_profiles.json ]]; then
	ui_print " " " Note : Uclamp Task Profile Not Found ! " " "
fi

ui_print " " " E404R Kernel @ Project113 "
ui_print " " " --- Install Complete --- "
