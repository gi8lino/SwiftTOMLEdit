#ifndef SWIFT_TOML_EDIT_H
#define SWIFT_TOML_EDIT_H

#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

char *swift_toml_edit_parse(const char *input);
char *swift_toml_edit_edit(const char *input, const char *request_json);
void swift_toml_edit_string_free(char *value);

#ifdef __cplusplus
}
#endif

#endif
