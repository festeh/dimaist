#!/usr/bin/env python3
"""Generate a flat Python client from swagger.json."""

import json
from pathlib import Path

HEADER = '''\
"""Dimaist API client — auto-generated from swagger.json."""

import httpx

BASE_URL = "http://localhost:3000"


def _url(path: str) -> str:
    return BASE_URL + path


def _check(r: httpx.Response) -> None:
    r.raise_for_status()

'''


def resolve_ref(spec: dict, ref: str) -> dict:
    parts = ref.lstrip("#/").split("/")
    node = spec
    for p in parts:
        node = node[p]
    return node


def schema_to_type(spec: dict, schema: dict) -> str:
    if "$ref" in schema:
        return "dict"
    t = schema.get("type", "object")
    if t == "integer":
        return "int"
    if t == "string":
        return "str"
    if t == "boolean":
        return "bool"
    if t == "array":
        item_type = schema_to_type(spec, schema.get("items", {}))
        return f"list[{item_type}]"
    return "dict"


def get_response_type(spec: dict, responses: dict) -> str:
    ok = responses.get("200", {})
    content = ok.get("content", {}).get("application/json", {})
    schema = content.get("schema")
    if not schema:
        return "None"
    return schema_to_type(spec, schema)


def get_body_schema(spec: dict, request_body: dict) -> dict:
    """Resolve the request body to a concrete schema."""
    content = request_body.get("content", {}).get("application/json", {})
    schema = content.get("schema", {})
    if "oneOf" in schema:
        for variant in schema["oneOf"]:
            if "$ref" in variant:
                return resolve_ref(spec, variant["$ref"])
            if variant.get("type") == "array":
                return variant
    if "$ref" in schema:
        return resolve_ref(spec, schema["$ref"])
    return schema


def get_body_fields(spec: dict, schema: dict) -> list[tuple[str, str, bool]]:
    """Return (name, type, required) for each body field."""
    if schema.get("type") == "array":
        return [("items", schema_to_type(spec, schema), True)]

    props = schema.get("properties", {})
    required_fields = set(schema.get("required", []))

    result = []
    for name, prop in props.items():
        result.append((name, schema_to_type(spec, prop), name in required_fields))
    return result


def generate(spec_path: Path, out_path: Path) -> None:
    spec = json.loads(spec_path.read_text())
    lines = [HEADER]

    for path, methods in sorted(spec["paths"].items()):
        for method, detail in sorted(methods.items()):
            op_id = detail.get("operationId")
            if not op_id:
                continue

            summary = detail.get("summary", "")
            params = detail.get("parameters", [])
            request_body = detail.get("requestBody")
            ret_type = get_response_type(spec, detail.get("responses", {}))

            # Collect args: required first, then optional
            required_args: list[str] = []
            optional_args: list[str] = []
            path_params: list[str] = []
            query_params: list[tuple[str, bool]] = []
            body_fields: list[tuple[str, str, bool]] = []

            for p in params:
                name = p["name"]
                p_type = schema_to_type(spec, p.get("schema", {}))
                required = p.get("required", False)
                if p["in"] == "path":
                    required_args.append(f"{name}: {p_type}")
                    path_params.append(name)
                elif p["in"] == "query":
                    if required:
                        required_args.append(f"{name}: {p_type}")
                    else:
                        optional_args.append(f"{name}: {p_type} | None = None")
                    query_params.append((name, required))

            if request_body:
                schema = get_body_schema(spec, request_body)
                body_fields = get_body_fields(spec, schema)
                for name, p_type, required in body_fields:
                    if required:
                        required_args.append(f"{name}: {p_type}")
                    else:
                        optional_args.append(f"{name}: {p_type} | None = None")

            args_str = ", ".join(required_args + optional_args)
            lines.append(f"def {op_id}({args_str}) -> {ret_type}:")
            lines.append(f'    """{summary}."""')

            # Build URL
            url_expr = path
            for pp in path_params:
                url_expr = url_expr.replace("{" + pp + "}", f"{{{pp}}}")
            if path_params:
                lines.append(f'    url = _url(f"{url_expr}")')
            else:
                lines.append(f'    url = _url("{url_expr}")')

            # Build query params
            if query_params:
                lines.append("    params = {}")
                for qp_name, _ in query_params:
                    lines.append(f"    if {qp_name} is not None:")
                    lines.append(f'        params["{qp_name}"] = {qp_name}')

            # Build body
            if body_fields:
                if len(body_fields) == 1 and body_fields[0][0] == "items":
                    lines.append("    body = items")
                else:
                    # Start with required fields, add optional if set
                    required_body = [(n, t) for n, t, r in body_fields if r]
                    optional_body = [(n, t) for n, t, r in body_fields if not r]
                    if required_body:
                        init = ", ".join(f'"{n}": {n}' for n, _ in required_body)
                        lines.append(f"    body: dict = {{{init}}}")
                    else:
                        lines.append("    body: dict = {}")
                    for bp_name, _ in optional_body:
                        lines.append(f"    if {bp_name} is not None:")
                        lines.append(f'        body["{bp_name}"] = {bp_name}')

            # Build the request call
            call_args = ["url"]
            if query_params:
                call_args.append("params=params")
            if body_fields:
                call_args.append("json=body")
            call_str = ", ".join(call_args)

            lines.append(f"    r = httpx.{method}({call_str})")
            lines.append("    _check(r)")

            if ret_type != "None":
                lines.append("    return r.json()")

            lines.append("")
            lines.append("")

    out_path.write_text("\n".join(lines))
    print(f"Generated {out_path}")


if __name__ == "__main__":
    here = Path(__file__).parent
    generate(here / "docs" / "swagger.json", here / "client.py")
