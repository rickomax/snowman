/* The file is part of Snowman decompiler. */
/* See doc/licenses.asciidoc for the licensing information. */

#pragma once

/*
 * Qt6 moved the QTextStream stream manipulators (endl, flush, hex, dec, ...)
 * out of the global namespace and into namespace Qt. Bring the ones Snowman
 * uses back into the global namespace so that existing "stream << endl" code
 * keeps compiling unchanged across Qt4, Qt5 and Qt6.
 */

#include <QtGlobal>
#include <QTextStream>

#if QT_VERSION >= QT_VERSION_CHECK(6, 0, 0)
using Qt::dec;
using Qt::endl;
using Qt::flush;
using Qt::hex;
#endif

/* vim:set et sts=4 sw=4: */
