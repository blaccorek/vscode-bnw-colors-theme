"""Sample Python module: dataclasses, typing, async, decorators, comprehensions."""

from __future__ import annotations

import asyncio
import logging
import re
from contextlib import asynccontextmanager
from dataclasses import dataclass, field
from enum import Enum, auto
from functools import cached_property, wraps
from typing import Any, AsyncIterator, Callable, Iterable, Optional, Protocol, TypeVar

logger = logging.getLogger(__name__)

T = TypeVar("T")
SLUG_RE: re.Pattern[str] = re.compile(r"[^a-z0-9]+")
MAX_RETRIES: int = 3
TIMEOUT: float = 5.0
FEATURE_FLAGS: dict[str, bool] = {"async_writes": True, "tracing": False}


class Status(Enum):
    IDLE = auto()
    RUNNING = auto()
    FAILED = auto()

    def __str__(self) -> str:
        return self.name.lower()


class Storage(Protocol):
    async def put(self, key: str, value: bytes) -> None: ...
    async def get(self, key: str) -> bytes | None: ...


@dataclass(slots=True, frozen=True)
class User:
    id: int
    name: str
    email: Optional[str] = None
    roles: tuple[str, ...] = field(default_factory=tuple)

    @cached_property
    def slug(self) -> str:
        return SLUG_RE.sub("-", self.name.lower()).strip("-")

    def has_role(self, *roles: str) -> bool:
        return any(role in self.roles for role in roles)


class RepositoryError(RuntimeError):
    """Raised when persistence fails."""

    def __init__(self, key: str, *, cause: Exception | None = None) -> None:
        super().__init__(f"failed to persist {key!r}")
        self.key = key
        self.__cause__ = cause


def retry(times: int = MAX_RETRIES, backoff: float = 0.25) -> Callable[..., Any]:
    def decorator(func):
        @wraps(func)
        async def wrapper(*args: Any, **kwargs: Any):
            last: Exception | None = None
            for attempt in range(1, times + 1):
                try:
                    return await func(*args, **kwargs)
                except Exception as exc:  # noqa: BLE001
                    last = exc
                    logger.warning("attempt %d/%d failed: %s", attempt, times, exc)
                    await asyncio.sleep(backoff * attempt)
            raise RepositoryError(getattr(func, "__name__", "?"), cause=last)

        return wrapper

    return decorator


class UserRepository:
    _instances = 0

    def __init__(self, storage: Storage, *, namespace: str = "users") -> None:
        self._storage = storage
        self.namespace = namespace
        type(self)._instances += 1

    def __repr__(self) -> str:
        return f"<{self.__class__.__name__} ns={self.namespace!r} n={len(self)}>"

    def __len__(self) -> int:
        return type(self)._instances

    @retry()
    async def save(self, user: User) -> User:
        await self._storage.put(f"{self.namespace}:{user.id}", user.name.encode("utf-8"))
        return user

    @staticmethod
    def partition(users: Iterable[User]) -> tuple[list[User], list[User]]:
        admins = [u for u in users if u.has_role("admin")]
        others = [u for u in users if not u.has_role("admin")]
        return admins, others


@asynccontextmanager
async def lifespan(repo: UserRepository) -> AsyncIterator[UserRepository]:
    logger.info("starting %r", repo)
    try:
        yield repo
    finally:
        logger.info("stopping %r", repo)


def describe(status: Status) -> str:
    match status:
        case Status.IDLE:
            return "waiting for work"
        case Status.RUNNING:
            return "processing…"
        case Status.FAILED:
            return "needs attention"
        case _:
            raise ValueError(f"unhandled status: {status}")


async def main() -> None:
    users = [
        User(1, "Ada Lovelace", "ada@example.com", ("admin",)),
        User(2, "Grace Hopper", roles=("editor", "viewer")),
    ]
    by_slug = {u.slug: u for u in users}
    total = sum(len(u.roles) for u in users)

    print(f"{len(users)} users, {total} roles, slugs={sorted(by_slug)}")
    print(describe(Status.RUNNING), 0b1010, 0o17, 0xFF, 1_000_000, 3.14e-2, complex(1, 2))


if __name__ == "__main__":
    asyncio.run(main())
