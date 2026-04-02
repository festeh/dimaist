"""Dimaist API client — auto-generated from swagger.json."""

import httpx

BASE_URL = "http://localhost:3000"


def _url(path: str) -> str:
    return BASE_URL + path


def _check(r: httpx.Response) -> None:
    r.raise_for_status()


def find_items(q: str) -> dict:
    """Search across tasks and projects."""
    url = _url("/find")
    params = {}
    if q is not None:
        params["q"] = q
    r = httpx.get(url, params=params)
    _check(r)
    return r.json()


def list_projects() -> list[dict]:
    """List all projects."""
    url = _url("/projects")
    r = httpx.get(url)
    _check(r)
    return r.json()


def create_project(name: str, color: str | None = None, icon: str | None = None, order: int | None = None) -> dict:
    """Create a new project."""
    url = _url("/projects")
    body: dict = {"name": name}
    if color is not None:
        body["color"] = color
    if icon is not None:
        body["icon"] = icon
    if order is not None:
        body["order"] = order
    r = httpx.post(url, json=body)
    _check(r)
    return r.json()


def reorder_projects(items: list[int]) -> None:
    """Reorder projects."""
    url = _url("/projects-reorder")
    body = items
    r = httpx.put(url, json=body)
    _check(r)


def delete_project(project_id: int) -> None:
    """Delete a project."""
    url = _url(f"/projects/{project_id}")
    r = httpx.delete(url)
    _check(r)


def update_project(project_id: int, color: str | None = None, icon: str | None = None, name: str | None = None, order: int | None = None) -> None:
    """Update a project."""
    url = _url(f"/projects/{project_id}")
    body: dict = {}
    if color is not None:
        body["color"] = color
    if icon is not None:
        body["icon"] = icon
    if name is not None:
        body["name"] = name
    if order is not None:
        body["order"] = order
    r = httpx.put(url, json=body)
    _check(r)


def reorder_project_tasks(project_id: int, items: list[int]) -> None:
    """Reorder tasks within a project."""
    url = _url(f"/projects/{project_id}/tasks/reorder")
    body = items
    r = httpx.put(url, json=body)
    _check(r)


def sync_data(sync_token: str | None = None) -> dict:
    """Sync data with incremental updates."""
    url = _url("/sync")
    params = {}
    if sync_token is not None:
        params["sync_token"] = sync_token
    r = httpx.get(url, params=params)
    _check(r)
    return r.json()


def list_tasks() -> list[dict]:
    """List all tasks."""
    url = _url("/tasks")
    r = httpx.get(url)
    _check(r)
    return r.json()


def create_task(title: str, description: str | None = None, due: str | None = None, end_datetime: str | None = None, has_time: bool | None = None, labels: list[str] | None = None, order: int | None = None, project_id: int | None = None, recurrence: str | None = None, reminders: list[str] | None = None, start_datetime: str | None = None) -> dict:
    """Create a new task."""
    url = _url("/tasks")
    body: dict = {"title": title}
    if description is not None:
        body["description"] = description
    if due is not None:
        body["due"] = due
    if end_datetime is not None:
        body["end_datetime"] = end_datetime
    if has_time is not None:
        body["has_time"] = has_time
    if labels is not None:
        body["labels"] = labels
    if order is not None:
        body["order"] = order
    if project_id is not None:
        body["project_id"] = project_id
    if recurrence is not None:
        body["recurrence"] = recurrence
    if reminders is not None:
        body["reminders"] = reminders
    if start_datetime is not None:
        body["start_datetime"] = start_datetime
    r = httpx.post(url, json=body)
    _check(r)
    return r.json()


def delete_task(task_id: int) -> None:
    """Delete a task."""
    url = _url(f"/tasks/{task_id}")
    r = httpx.delete(url)
    _check(r)


def get_task(task_id: int) -> dict:
    """Get a task by ID."""
    url = _url(f"/tasks/{task_id}")
    r = httpx.get(url)
    _check(r)
    return r.json()


def update_task(task_id: int, description: str | None = None, due: str | None = None, end_datetime: str | None = None, has_time: bool | None = None, labels: list[str] | None = None, order: int | None = None, project_id: int | None = None, recurrence: str | None = None, reminders: list[str] | None = None, start_datetime: str | None = None, title: str | None = None) -> dict:
    """Update a task."""
    url = _url(f"/tasks/{task_id}")
    body: dict = {}
    if description is not None:
        body["description"] = description
    if due is not None:
        body["due"] = due
    if end_datetime is not None:
        body["end_datetime"] = end_datetime
    if has_time is not None:
        body["has_time"] = has_time
    if labels is not None:
        body["labels"] = labels
    if order is not None:
        body["order"] = order
    if project_id is not None:
        body["project_id"] = project_id
    if recurrence is not None:
        body["recurrence"] = recurrence
    if reminders is not None:
        body["reminders"] = reminders
    if start_datetime is not None:
        body["start_datetime"] = start_datetime
    if title is not None:
        body["title"] = title
    r = httpx.put(url, json=body)
    _check(r)
    return r.json()


def complete_task(task_id: int) -> None:
    """Mark a task as complete."""
    url = _url(f"/tasks/{task_id}/complete")
    r = httpx.post(url)
    _check(r)

