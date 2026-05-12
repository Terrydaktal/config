#!/usr/bin/env bash
set -euo pipefail

ESC=$'\033'
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
DIRCOLORS_FILE="${LS_COLOURS_FILE:-}"

if [[ -z "$DIRCOLORS_FILE" ]]; then
  if [[ -f "$HOME/.config/fish/ls_colours.dircolors" ]]; then
    DIRCOLORS_FILE="$HOME/.config/fish/ls_colours.dircolors"
  elif [[ -f "$SCRIPT_DIR/fish/ls_colours.dircolors" ]]; then
    DIRCOLORS_FILE="$SCRIPT_DIR/fish/ls_colours.dircolors"
  elif [[ -f "$SCRIPT_DIR/ls_colours.dircolors" ]]; then
    DIRCOLORS_FILE="$SCRIPT_DIR/ls_colours.dircolors"
  fi
fi

if [[ -z "$DIRCOLORS_FILE" || ! -f "$DIRCOLORS_FILE" ]]; then
  printf 'Missing dircolors file. Set LS_COLOURS_FILE or provide one of:\n' >&2
  printf '  - %s\n' "$HOME/.config/fish/ls_colours.dircolors" >&2
  printf '  - %s\n' "$SCRIPT_DIR/fish/ls_colours.dircolors" >&2
  printf '  - %s\n' "$SCRIPT_DIR/ls_colours.dircolors" >&2
  exit 1
fi

declare -A EXT CORE_STYLE EXT_STYLE NAME_STYLE

EXT[EXECUTABLE]='elf bin run out core dump com scr exe sfx'
EXT[PACKAGE]='deb rpm pkg appimage snap flatpak msi dmg xar cab whl gem crate nupkg apkg cpq pkpass unitypackage msp vsix xpi pk3 pk4 jar war ear pkg.tar.zst pkg.tar.xz pyz pyzw'
EXT[FULLY_SOURCE_INTERPRETED]='sh bash zsh fish ksh dtksh tcsh csh xsh bat cmd vbs cgi script postinst prerm remove nu awk sed html htm xhtml xul css htp htmt mhtml mht webmanifest scss sass less styl pug jade hbs handlebars ejs jst tpl njk liquid wxml kv nix graphql guess web'
EXT[FULLY_BYTECODE_INTERPRETED]='py pyw py-tpl rb php pl pm perl t erl hrl xrl yrl ex exs eex heex leex lua tcl r'
EXT[HYBRID_BYTECODE_JIT]='java scala kt kts clj cljs cljc groovy gvy gsh jsp cs vb fs fsx fsi ps1 psm1 psd1 asp aspx ashx js mjs cjs jsx tsx vue svelte astro coffee elm purs jl raku rakumod rkt ss sls'
EXT[AOT_NATIVE]='c cpp cc cxx dxx cp h hh hpp hxx rh def ixx inl tpp mpp rs go swift m mm mmh mi prefix x zig nim cr v d dart pas pp cob cbl ada ads adb f f90 f95 f03 f08 f77 fpp for l y hs lhs ml mli lisp vala cu cuh metal mojo hlsli hlsl glsl vsh vert frag geom tesc tese comp wgsl idl odl sdef mc'
EXT[ASSEMBLED_NATIVE]='asm s S arm asmx a51 src inc mac ms z80'
EXT[CONFIG]='conf cfg config ini rc desktop service socket timer target mount path slice scope properties cnf rules repo sources list plist override example local suo session user rgs araloc xrc browser manifest resx acf client policy klc inx sif mozilla gamecenter url sample metadata mf server fsd vcl opt mof nss tdf reg inf sys cpl tf tfvars hcl nomad pkr.hcl lock gitignore'
EXT[TEXT]='txt md markdown rst tex ltx sty bib bibtex asciidoc adoc org man 1 7 8 1st readme info nfo textile creole wiki sgml pod troff roff lsm homework me'
EXT[LOG]='log syslog dmesg journal audit err trace tlog status clog plg'
EXT[PLAIN_TEXT_DATA]='yml yaml toml json jsonl ndjson xml csv tsv tab tbl xsd xsl xslt dtd rdf rss proto po srt sub ass sql diff patch dic nt elst tst extra text strings lst ver eng rus api rep uid utf8 charset head tail top files ldif fortune xbel xmlterm aff quick label mn geojson kml vcf ics'
EXT[BINARY_DATA]='avro parquet orc arrow feather dat bytes assets resource rsrc ber stb 3t static bili huawei toolhelp pcap vng_meta small sgame timegm pickle nls mo idx index torrent uf ut una abm ids shp shx gpkg kmz npy pkl pth onnx qm predec'
EXT[ARCHIVE]='tar ar cpio'
EXT[COMPRESSED_ARCHIVES]='zip zipx tar.gz tar.bz2 tar.xz tar.lz tar.lzma tar.lzo 7z rar r00 r[0-9][0-9] x01 x[0-9][0-9] z[0-9][0-9] [0-9][0-9][0-9] part[0-9]* zi tgz tbz tbz2 txz tlz tzst ace arc npz'
EXT[COMPRESSED]='gz z bz2 xz zst zstd lz4 lzma lzo lz Z compr compression'
EXT[DATABASE]='db db2 sqlite sqlite3 db3 sdb mdb accdb fdb mdf ndf ldf sqlite-shm sqlite-wal frm ibd myd myi dbf fp ntx anki2 mat h5 hdf5 nc'
EXT[VIRTUALIZATION]='vmdk vdi vhd vhdx ova ovf box vmem vmsd vmx vbox vcb pvm hdd hds'
EXT[BUILD]='mk make mak jam icf ac am m4 lds win mms msvc evc3 evc4 evc8 evc9 wince unixes w32api windows linux mingw cygwin intel reactos unix lnx wine amd64 win32 win98 solaris solaris2 alpha debian targ dirs order cmake gradle pom ant bazel bzl meson ninja makefile hin spec in substvars debhelper ros nsi vc df dockerfile containerfile Cargo.toml go.mod go.sum package.json pyproject.toml setup.py setup.cfg requirements.txt Gemfile Gemfile.lock Podfile build.gradle settings.gradle pom.xml build.sbt mix.exs Makefile makefile Dockerfile Containerfile conanfile.txt conanfile.py vcpkg.json platformio.ini CMakeLists.txt meson.build bld.inf mmp'
EXT[SHELL_ENV]='env profile bashrc zshrc inputrc dircolors vim alias'
EXT[OBJECT]='o obj pdb dsym gch pch pch++ dep ilk idb tds exp res aps ap_ ipch ncb sbr bsc map ccmap x-ccmap vco frx dcu ppob rmeta'
EXT[BYTECODE]='class pyc pyo luac rbc beam wasm il netmodule dex odex vdex oat art spv spirv ptx bc ll wat ex4 rpyb bxb'
EXT[LIBRARY]='so dll dlls dylib a lib la pyd node ko ocx framework bundle dll.a mod vxd dsl'
EXT[DISK_IMAGE]='iso eltorito joliet img raw rom gen amiga wim qcow2 qcow squashfs cramfs'
EXT[CRYPTO]='pem crt cer der pub csr asc sig md5 sha1 sha224 sha256 sha384 sha512 sha3 blake2 blake3 sfv jwt rsa sf'
EXT[ENCRYPTED]='enc gpg luks crypt* age p7m pgp pfx p12 aes axx tird ct kdbx'
EXT[IMAGE]='jpg jpeg jpe jpg_large dcr thm xif ppmx cin png gif bmp tga dds tiff tif svg emf ico cur pct ptr webp heic heif avif jxl jp2 j2k jpf jpx wdp hdp jxr apng tgs thumbnail dng 3fr cr2 cr3 nef nrw orf pef arw rw2 srw raf sr2 erf kdc mef mrw exr hdr icns eps pcx pnm pam pbm pgm ppm xpm xbm'
EXT[3D_IMAGE]='dcm dicom nii fits nrrd nhdr mnc v3d vff gipl gipl.gz mgz t1'
EXT[PROJECT]='psd psb xcf ai ind kra clip sketch fig afdesign afphoto afpub blend pdn kdenlive aup3 prproj aep fla ino iml sln xcodeproj pbxproj storyboard xib nib ui pro pri qbs godot unity uplugin uproject prj bpr dof dfm fsproj vbproj vbp csproj vcxproj vcproj filters hhc hhp dsp dsw mdp mcp ewp ewd eww vcp vcn vcw bds sbt'
EXT[AUDIO]='mp3 wav flac ogg oga m4a m4b aac opus wma mid midi aiff aif alac au snd weba caf tta wv mpc 3ga mka mp1 mp2 aa aax it dmc imy spx amr ape ac3 dts ra'
EXT[VIDEO]='mp4 avi mkv mov wmv flv webm m4v ts qt mpeg mpg mpe mpv mp2v m1v m2v divx amv drc y4m h264 h265 264 265 vivo avs m3u8 3gp 3g2 vob ogv m2ts mts mxf asf rm rmvb f4v'
EXT[FONT_BINARY]='ttf otf woff woff2 eot pfb pfm bmf pcf ttc fon snf'
EXT[FONT_TEXT]='pfa bdf ufo sfd'
EXT[DOCUMENT]='pdf ps cdf chm tph sda dj et doc docx docm dot dotx xls xlsx xlsm xltx ppt pptx pptm potx odf odt ott ods ots odp otp odg odm sxw sxc sxi rtf key abw lrf cbz cbr oxps xps wpd pages numbers djvu eml msg mbox pst ost maildir epub mobi azw azw3 fb2'
EXT[MOBILE]='apk apks xapk apkm aab ipa appx appxbundle msix msixbundle'
EXT[3D_GRAPHICS]='stl wrl x3d x3db fbx dae gltf glb ply step stp iges igs dwg dxf 3ds max ma mb usdz white pial inflated sphere flat smoothwm premesh preaparc annot crv'
EXT[BACKUP_TEMPORARY]='0 100 215 orig nofix'
EXT[DEFAULT]='(fallback for uncategorized files)'

cluster_names=(
  'Greens'
  'Teals'
  'Greys'
  'Oranges'
  'Pinks/Purples'
  'Pink'
  'Red'
  'Light Blues'
  'Default'
  'Brown'
)

clusters=(
  'FULLY_SOURCE_INTERPRETED FULLY_BYTECODE_INTERPRETED HYBRID_BYTECODE_JIT AOT_NATIVE ASSEMBLED_NATIVE BUILD BINARY_DATA'
  'EXECUTABLE OBJECT BYTECODE LIBRARY FONT_BINARY'
  'CONFIG TEXT LOG PLAIN_TEXT_DATA SHELL_ENV CRYPTO FONT_TEXT BACKUP_TEMPORARY'
  'ARCHIVE COMPRESSED_ARCHIVES PACKAGE MOBILE COMPRESSED ENCRYPTED'
  'IMAGE 3D_IMAGE 3D_GRAPHICS VIRTUALIZATION DISK_IMAGE'
  'VIDEO'
  'AUDIO'
  'DOCUMENT PROJECT'
  'DEFAULT'
  'DATABASE'
)

paint_seq() {
  local seq="$1"
  local text="$2"
  if [[ -n "$seq" ]]; then
    printf '%b%s%b' "${ESC}[${seq}m" "$text" "${ESC}[0m"
  else
    printf '%s' "$text"
  fi
}

style_has_bold() {
  local seq="$1"
  [[ ";${seq};" == *";1;"* ]]
}

style_has_italic() {
  local seq="$1"
  [[ ";${seq};" == *";3;"* ]]
}

style_has_underline() {
  local seq="$1"
  [[ ";${seq};" == *";4;"* ]]
}

extract_fg_rgb() {
  local seq="$1"
  if [[ "$seq" =~ 38\;2\;([0-9]+)\;([0-9]+)\;([0-9]+) ]]; then
    printf '%s;%s;%s' "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}" "${BASH_REMATCH[3]}"
  fi
}

extract_bg_rgb() {
  local seq="$1"
  if [[ "$seq" =~ 48\;2\;([0-9]+)\;([0-9]+)\;([0-9]+) ]]; then
    printf '%s;%s;%s' "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}" "${BASH_REMATCH[3]}"
  fi
}

rgb_to_hex() {
  local rgb="$1"
  local r g b
  IFS=';' read -r r g b <<<"$rgb"
  printf '#%02X%02X%02X' "$r" "$g" "$b"
}

style_description() {
  local seq="$1"
  local fg bg desc
  fg="$(extract_fg_rgb "$seq")"
  bg="$(extract_bg_rgb "$seq")"
  desc=""

  if [[ -n "$fg" ]]; then
    desc="fg $(rgb_to_hex "$fg")"
  fi
  if [[ -n "$bg" ]]; then
    if [[ -n "$desc" ]]; then
      desc+=", "
    fi
    desc+="bg $(rgb_to_hex "$bg")"
  fi
  if style_has_bold "$seq"; then
    if [[ -n "$desc" ]]; then
      desc+=", "
    fi
    desc+="bold"
  fi
  if style_has_italic "$seq"; then
    if [[ -n "$desc" ]]; then
      desc+=", "
    fi
    desc+="italic"
  fi
  if style_has_underline "$seq"; then
    if [[ -n "$desc" ]]; then
      desc+=", "
    fi
    desc+="underline"
  fi

  if [[ -z "$desc" ]]; then
    desc="$seq"
  fi
  printf '%s' "$desc"
}

load_dircolors() {
  local key value rest
  while read -r key value rest; do
    [[ -z "${key:-}" ]] && continue
    [[ "${key:0:1}" == "#" ]] && continue
    [[ "$key" == "TERM" ]] && continue

    if [[ "$key" == ".*" ]]; then
      NAME_STYLE[".*"]="$value"
    elif [[ "$key" == \*.* ]]; then
      EXT_STYLE["${key:2}"]="$value"
    elif [[ "$key" == \** ]]; then
      NAME_STYLE["${key:1}"]="$value"
    else
      CORE_STYLE["$key"]="$value"
    fi
  done <"$DIRCOLORS_FILE"
}

style_for_token() {
  local token="$1"
  local style=""

  if [[ -n "${EXT_STYLE[$token]-}" ]]; then
    style="${EXT_STYLE[$token]}"
  elif [[ -n "${NAME_STYLE[$token]-}" ]]; then
    style="${NAME_STYLE[$token]}"
  elif [[ -n "${NAME_STYLE[${token,,}]-}" ]]; then
    style="${NAME_STYLE[${token,,}]}"
  elif [[ -n "${NAME_STYLE[${token^}]-}" ]]; then
    style="${NAME_STYLE[${token^}]}"
  elif [[ -n "${NAME_STYLE[${token^^}]-}" ]]; then
    style="${NAME_STYLE[${token^^}]}"
  else
    style="${CORE_STYLE[FILE]-38;2;255;255;255}"
  fi

  printf '%s' "$style"
}

print_extensions() {
  local list="$1"
  local count=0
  local token style rgb label
  local -a tokens=()

  if [[ "$list" == "(fallback for uncategorized files)" ]]; then
    style="${CORE_STYLE[FILE]-38;2;255;255;255}"
    paint_seq "$style" "$list"
    printf '\n'
    return
  fi

  read -r -a tokens <<<"$list"

  for token in "${tokens[@]}"; do
    style="$(style_for_token "$token")"
    if [[ "$token" == ".*" || "$token" == \** ]]; then
      label="$token"
    elif [[ -n "${EXT_STYLE[$token]-}" ]]; then
      label="*.${token}"
    elif [[ -n "${NAME_STYLE[$token]-}" || -n "${NAME_STYLE[${token,,}]-}" || -n "${NAME_STYLE[${token^}]-}" || -n "${NAME_STYLE[${token^^}]-}" ]]; then
      label="*${token}"
    else
      label="*.${token}"
    fi

    paint_seq "$style" "$label"
    printf '  '

    count=$((count + 1))
    if (( count % 8 == 0 )); then
      printf '\n'
    fi
  done

  if (( count % 8 != 0 )); then
    printf '\n'
  fi
}

print_core_item() {
  local key="$1"
  local label="$2"
  local seq

  seq="${CORE_STYLE[$key]-}"
  if [[ -z "$seq" ]]; then
    return
  fi

  paint_seq "$seq" "$label"

  printf ' %s\n' "$(style_description "$seq")"
}

load_dircolors

for i in "${!clusters[@]}"; do
  printf '\n'
  printf '%s\n' '============================================================'
  printf '%s\n' "${cluster_names[$i]^^}"
  printf '%s\n' '------------------------------------------------------------'

  for group in ${clusters[$i]}; do
    local_list="${EXT[$group]}"
    if [[ "$local_list" == "(fallback for uncategorized files)" ]]; then
      group_style="${CORE_STYLE[FILE]-38;2;255;255;255}"
    else
      first_token="${local_list%% *}"
      group_style="$(style_for_token "$first_token")"
    fi

    group_rgb="$(extract_fg_rgb "$group_style")"
    [[ -z "$group_rgb" ]] && group_rgb='255;255;255'
    group_hex="$(rgb_to_hex "$group_rgb")"
    group_label="$group"
    if [[ "$group" == "PACKAGE" ]]; then
      group_label='Packages (Compressed)'
    elif [[ "$group" == "MOBILE" ]]; then
      group_label='Mobile (Compressed)'
    elif [[ "$group" == "FULLY_SOURCE_INTERPRETED" ]]; then
      group_label='Fully Source-Interpreted Languages'
    elif [[ "$group" == "FULLY_BYTECODE_INTERPRETED" ]]; then
      group_label='Fully Bytecode-Interpreted Languages'
    elif [[ "$group" == "HYBRID_BYTECODE_JIT" ]]; then
      group_label='Hybrid Bytecode-Interpreted / JIT-Compiled Languages'
    elif [[ "$group" == "AOT_NATIVE" ]]; then
      group_label='AOT-Native Languages (Ahead-of-Time)'
    elif [[ "$group" == "ASSEMBLED_NATIVE" ]]; then
      group_label='Assembled-Native Languages'
    elif [[ "$group" == "BUILD" ]]; then
      group_label='Build Config'
    elif [[ "$group" == "PLAIN_TEXT_DATA" ]]; then
      group_label='Plain Text Data'
    elif [[ "$group" == "BINARY_DATA" ]]; then
      group_label='Binary Data'
    elif [[ "$group" == "OBJECT" ]]; then
      group_label='BUILD ARTIFACTS'
    elif [[ "$group" == "FONT_BINARY" ]]; then
      group_label='Font (Binary)'
    elif [[ "$group" == "FONT_TEXT" ]]; then
      group_label='Font (Text)'
    elif [[ "$group" == "BACKUP_TEMPORARY" ]]; then
      group_label='Backup / Temporary'
    elif [[ "$group" == "3D_GRAPHICS" ]]; then
      group_label='3D Graphics'
    elif [[ "$group" == "3D_IMAGE" ]]; then
      group_label='3D Image'
    fi

    group_label="${group_label^^}"

    printf '\n'
    paint_seq "$group_style" "$group_label"
    printf ' %s (%s) - from %s\n' "$group_hex" "${group_rgb//;/,}" "$DIRCOLORS_FILE"
    print_extensions "$local_list"
  done
done

printf '\n'
printf '%s\n' '============================================================'
printf '%s\n' 'Core File Types And States'
printf '%s\n' '------------------------------------------------------------'
printf '\n'

print_core_item 'DIR' 'DIR (directories)'
print_core_item 'LINK' 'LINK (symlinks)'
print_core_item 'EXEC' 'EXEC (executable bit set)'
print_core_item 'FILE' 'FILE (plain regular file)'
print_core_item 'ORPHAN' 'ORPHAN (broken symlink)'
print_core_item 'MISSING' 'MISSING (missing file reference)'
print_core_item 'SETUID' 'SETUID'
print_core_item 'SETGID' 'SETGID'
print_core_item 'CAPABILITY' 'CAPABILITY'
print_core_item 'BLK' 'BLK (block devices)'
print_core_item 'CHR' 'CHR (char devices)'
print_core_item 'FIFO' 'FIFO'
print_core_item 'SOCK' 'SOCK'
print_core_item 'DOOR' 'DOOR'
print_core_item 'MULTIHARDLINK' 'MULTIHARDLINK'
print_core_item 'STICKY' 'STICKY'
print_core_item 'OTHER_WRITABLE' 'OTHER_WRITABLE'
print_core_item 'STICKY_OTHER_WRITABLE' 'STICKY_OTHER_WRITABLE'
