<?php

declare(strict_types=1);

namespace App\Http\Controllers;

use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Cache;
use JsonSerializable;

enum Role: string
{
    case Admin = 'admin';
    case Editor = 'editor';
    case Viewer = 'viewer';

    public function label(): string
    {
        return match ($this) {
            Role::Admin => 'Full access',
            Role::Editor, Role::Viewer => 'Limited access',
        };
    }
}

interface Repository
{
    public function find(int $id): ?object;
}

trait Timestamps
{
    protected ?string $createdAt = null;

    public function touch(): static
    {
        $this->createdAt ??= date(DATE_ATOM);

        return $this;
    }
}

final class UserDto implements JsonSerializable
{
    use Timestamps;

    public const VERSION = '1.4.2';
    private const MAX_RETRIES = 3;

    /** @param list<Role> $roles */
    public function __construct(
        public readonly int $id,
        public readonly string $name,
        public readonly ?string $email = null,
        private array $roles = [],
    ) {
    }

    public function hasRole(Role ...$roles): bool
    {
        foreach ($roles as $role) {
            if (in_array($role, $this->roles, true)) {
                return true;
            }
        }

        return false;
    }

    public function jsonSerialize(): array
    {
        return [
            'id' => $this->id,
            'name' => $this->name,
            'email' => $this->email ?? null,
            'roles' => array_map(static fn (Role $r): string => $r->value, $this->roles),
            'created_at' => $this->createdAt,
        ];
    }
}

class UserController
{
    public function __construct(private readonly ?Repository $repository = null)
    {
    }

    public function index(Request $request): JsonResponse
    {
        $perPage = (int) $request->query('per_page', '25');
        $search = trim((string) $request->query('q', ''));

        $users = Cache::remember("users:{$perPage}:{$search}", 300, function () use ($perPage, $search): array {
            $query = User::query()->orderBy('name');

            if ($search !== '') {
                $query->where('name', 'like', "%{$search}%");
            }

            return $query->limit($perPage)->get()->all();
        });

        $payload = array_values(array_filter(array_map(
            fn ($user): ?UserDto => $user->id > 0
                ? (new UserDto($user->id, $user->name, $user->email, [Role::Viewer]))->touch()
                : null,
            $users,
        )));

        return response()->json([
            'data' => $payload,
            'meta' => ['count' => count($payload), 'version' => UserDto::VERSION],
        ], 200, ['X-Total-Count' => (string) count($payload)]);
    }

    public function show(int $id): JsonResponse
    {
        try {
            $user = $this->repository?->find($id) ?? throw new \RuntimeException("user {$id} not found");
        } catch (\RuntimeException $e) {
            return response()->json(['error' => $e->getMessage()], 404);
        } finally {
            logger()->debug('lookup finished', ['id' => $id]);
        }

        return response()->json($user);
    }
}

$heredoc = <<<SQL
    SELECT id, name
      FROM users
     WHERE deleted_at IS NULL
SQL;

printf("%s | %d | %.2f | %s%s", UserDto::VERSION, 0xFF, 3.14, $heredoc !== '' ? 'ok' : 'empty', PHP_EOL);
