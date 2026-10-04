// SPDX-License-Identifier: GPL-2.0-or-later
//
// C bridge between the SpeedCrunch C++/QtCore engine and the Swift app.
// All functions returning char* hand back a malloc'd UTF-8 JSON string that
// the caller must release with sc_free(). The engine is not thread-safe; call
// it from one thread (the Swift side confines it to the main actor).

#ifndef SPEEDCRUNCH_ENGINE_H
#define SPEEDCRUNCH_ENGINE_H

#ifdef __cplusplus
extern "C" {
#endif

void sc_init(void);
void sc_free(char* s);

// Evaluates and commits (assignments, `ans`). Returns
// {"ok":bool,"error":str,"kind":"value|variable|function|unit|comment|none",
//  "expression":str,"interpreted":str,"result":str,"bits":str}
// "bits" (binary digits, no prefix/sign) is present for integer results.
char* sc_evaluate(const char* expr);

// Side-effect free evaluation for the live result preview. Same shape.
char* sc_preview(const char* expr);

// {"angleUnit":"r|d|g|t|v","resultFormat":"g|f|e|n|s|h|o|b","precision":int,
//  "complexNumbers":bool,"complexForm":"r|e|t|c|p","imaginaryUnit":"i|j",
//  "numberFormatStyle":int,"secondaryFormat":"" | fmt}
void sc_apply_settings(const char* json);

char* sc_builtin_functions(void);   // [{"id","name","usage","domain"}]
char* sc_constants(void);           // [{"name","value","unit","domain","subdomain"}]
char* sc_user_variables(void);      // [{"id","value","description"}]
char* sc_user_functions(void);      // [{"name","args":[..],"expression","description"}]
char* sc_user_units(void);          // [{"name","expression","description"}]
char* sc_completions(const char* prefix); // [{"text","kind","detail"}]
char* sc_book_page(const char* id);       // Formula book page HTML (not JSON); "" = index

void sc_unset_variable(const char* id);
void sc_unset_function(const char* name);
void sc_unset_unit(const char* name);
void sc_reset(void); // Clears all user definitions and `ans`.

#ifdef __cplusplus
}
#endif

#endif
