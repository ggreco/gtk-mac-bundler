#!/bin/sh

if test "x$GTK_DEBUG_LAUNCHER" != x; then
    set -x
fi

if test "x$GTK_DEBUG_GDB" != x; then
    EXEC="gdb --args"
else
    EXEC=exec
fi

name=`basename "$0"`
tmp="$0"
tmp=`dirname "$tmp"`
tmp=`dirname "$tmp"`
bundle=`dirname "$tmp"`
bundle_contents="$bundle"/Contents
bundle_res="$bundle_contents"/Resources
bundle_lib="$bundle_res"/lib
bundle_bin="$bundle_res"/bin
bundle_data="$bundle_res"/share
bundle_etc="$bundle_res"/etc

export XDG_CONFIG_DIRS="$bundle_etc"/xdg
export XDG_DATA_DIRS="$bundle_data"
export GTK_DATA_PREFIX="$bundle_res"
export GTK_EXE_PREFIX="$bundle_res"
export GTK_PATH="$bundle_res"

# PANGO_* is no longer needed for pango >= 1.38
export PANGO_RC_FILE="$bundle_etc/pango/pangorc"
export PANGO_SYSCONFDIR="$bundle_etc"
export PANGO_LIBDIR="$bundle_lib"

export GDK_PIXBUF_MODULE_FILE="$bundle_lib/gdk-pixbuf-2.0/2.10.0/loaders.cache"
if [ `uname -r | cut -d . -f 1` -ge 10 ]; then
    export GTK_IM_MODULE_FILE="$bundle_lib/gtk-3.0/3.0.0/immodules.cache"
fi

APP=$name
I18NDIR="$bundle_data/locale"
# Set the locale-related variables appropriately:
unset LANG LC_MESSAGES LC_MONETARY LC_COLLATE

# Has a language ordering been set?
# If so, set LC_MESSAGES and LANG accordingly; otherwise skip it.
# First step uses sed to clean off the quotes and commas, to change - to _, and change the names for the chinese scripts from "Hans" to CN and "Hant" to TW.
APPLELANGUAGES=`defaults read .GlobalPreferences AppleLanguages | sed -En   -e 's/\-/_/' -e 's/Hant/TW/' -e 's/Hans/CN/' -e 's/[[:space:]]*\"?([[:alnum:]_]+)\"?,?/\1/p' `
if test "$APPLELANGUAGES"; then
    # A language ordering exists.
    # Test, item per item, to see whether there is an corresponding locale.
    for L in $APPLELANGUAGES; do
        #test for exact matches:
       if test -f "$I18NDIR/${L}/LC_MESSAGES/$APP.mo"; then
            export LANG=$L
            break
        fi
        # This is a special case, because often the original strings are in US
        # English and there is no translation file.
        if test "x$L" == "xen_US"; then
            export LANG=$L
            break
        fi
        #OK, now test for just the first two letters:
        if test -f "$I18NDIR/${L:0:2}/LC_MESSAGES/$APP.mo"; then
            export LANG=${L:0:2}
            break
        fi
        #Same thing, but checking for any english variant.
        if test "x${L:0:2}" == "xen"; then
            export LANG=$L
            break
        fi;
    done
fi
unset APPLELANGUAGES L

# If we didn't get a language from the language list, try the Collation preference, in case it's the only setting that exists.
APPLECOLLATION=`defaults read .GlobalPreferences AppleCollationOrder`
if test -z ${LANG} && test -n $APPLECOLLATION; then
    if test -f "$I18NDIR/${APPLECOLLATION:0:2}/LC_MESSAGES/$APP.mo"; then
        export LANG=${APPLECOLLATION:0:2}
    fi
fi
if test -n $APPLECOLLATION; then
    export LC_COLLATE=$APPLECOLLATION
fi
unset APPLECOLLATION

# Continue by attempting to find the Locale preference.
APPLELOCALE=`defaults read .GlobalPreferences AppleLocale`

if test -f "$I18NDIR/${APPLELOCALE:0:5}/LC_MESSAGES/$APP.mo"; then
    if test -z $LANG; then
        export LANG="${APPLELOCALE:0:5}"
    fi

elif test -z $LANG && test -f "$I18NDIR/${APPLELOCALE:0:2}/LC_MESSAGES/$APP.mo"; then
    export LANG="${APPLELOCALE:0:2}"
fi

# Next we need to set LC_MESSAGES. If at all possible, we want a full
# 5-character locale to avoid the "Locale not supported by C library"
# warning from Gtk -- even though Gtk will translate with a
# two-character code.
if test -n $LANG; then
    # If the language code matches the applelocale, then that's the message
    # locale; otherwise, if it's longer than two characters, then it's
    # probably a good message locale and we'll go with it.
    if test $LANG == ${APPLELOCALE:0:5} || test $LANG != ${LANG:0:2}; then
        export LC_MESSAGES=$LANG
# Next try if the Applelocale is longer than 2 chars and the language
# bit matches $LANG
    elif test $LANG == ${APPLELOCALE:0:2} && test $APPLELOCALE > ${APPLELOCALE:0:2}; then
        export LC_MESSAGES=${APPLELOCALE:0:5}
    # Fail. Get a list of the locales in $I18DIR that match
    # our two letter language code and pick the first one, special casing
    # english to set en_US
    elif test $LANG == "en"; then
        export LC_MESSAGES="en_US"
    else
        LOC=`find $I18DIR -name $LANG???`
        for L in $LOC; do
            export LC_MESSAGES=$L
        done
    fi
else
    # All efforts have failed, so default to US english
    export LANG="en_US"
    export LC_MESSAGES="en_US"
fi
CURRENCY=`echo $APPLELOCALE |  sed -En 's/.*currency=([[:alpha:]]+).*/\1/p'`
if test -n "$CURRENCY"; then
   # The user has set a special currency. Gtk doesn't install
   # LC_MONETARY files, but Apple does in /usr/share/locale, so we're
   # going to look there for a locale to set LC_CURRENCY to.
    if test -f /usr/local/share/$LC_MESSAGES/LC_MONETARY; then
        if test `cat /usr/local/share/$LC_MESSAGES/LC_MONETARY` == $CURRENCY; then
            export LC_MONETARY=$LC_MESSAGES
        fi
    fi
    if test -z "$LC_MONETARY"; then
        FILES=`find /usr/share/locale -name LC_MONETARY -exec grep -H $CURRENCY {} \;`
        if test -n "$FILES"; then
            export LC_MONETARY=`echo $FILES | sed -En 's%/usr/share/locale/([[:alpha:]_]+)/LC_MONETARY.*%\1%p'`
        fi
    fi
fi
# No currency value means that the AppleLocale governs:
if test -z "$LC_MONETARY"; then
    LC_MONETARY=${APPLELOCALE:0:5}
fi
# For Gtk, which only looks at LC_ALL:
export LC_ALL=$LC_MESSAGES

unset APPLELOCALE FILES LOC

if test -f "$bundle_lib/charset.alias"; then
    export CHARSETALIASDIR="$bundle_lib"
fi

# Extra arguments can be added in environment.sh.
EXTRA_ARGS=
if test -f "$bundle_res/environment.sh"; then
    source "$bundle_res/environment.sh"
fi

# Strip out the argument added by the OS.
if /bin/expr "x$1" : '^x-psn_' > /dev/null; then
    shift 1
fi

$EXEC "$bundle_contents/MacOS/$name-bin" "$@" $EXTRA_ARGS
