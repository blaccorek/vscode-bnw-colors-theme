// Sample C#: namespaces, records, LINQ, async/await, pattern matching, generics.
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text.Json.Serialization;
using System.Threading;
using System.Threading.Tasks;

namespace Bnw.Samples.Users;

public enum Role
{
    Admin,
    Editor,
    Viewer,
}

public record User(long Id, string Name, string? Email = null)
{
    [JsonPropertyName("roles")]
    public IReadOnlyList<Role> Roles { get; init; } = Array.Empty<Role>();

    public bool HasRole(Role role) => Roles.Contains(role);

    public override string ToString() => $"#{Id} {Name} <{Email ?? "n/a"}>";
}

public sealed class RepositoryException : Exception
{
    public RepositoryException(string key, Exception? inner = null)
        : base($"failed to persist '{key}'", inner) => Key = key;

    public string Key { get; }
}

public interface IRepository<T> where T : class
{
    Task<T?> GetAsync(long id, CancellationToken ct = default);

    Task SaveAsync(T item, CancellationToken ct = default);
}

public class UserRepository : IRepository<User>
{
    private const int MaxRetries = 3;
    private static readonly TimeSpan Backoff = TimeSpan.FromMilliseconds(250);

    private readonly Dictionary<long, User> _items = new();
    private readonly object _gate = new();

    public int Count => _items.Count;

    public Task<User?> GetAsync(long id, CancellationToken ct = default)
    {
        ct.ThrowIfCancellationRequested();

        lock (_gate)
        {
            return Task.FromResult(_items.TryGetValue(id, out var user) ? user : null);
        }
    }

    public async Task SaveAsync(User item, CancellationToken ct = default)
    {
        ArgumentNullException.ThrowIfNull(item);

        for (var attempt = 1; attempt <= MaxRetries; attempt++)
        {
            try
            {
                lock (_gate)
                {
                    _items[item.Id] = item;
                }

                return;
            }
            catch (Exception ex) when (attempt < MaxRetries)
            {
                Console.Error.WriteLine($"attempt {attempt}/{MaxRetries}: {ex.Message}");
                await Task.Delay(Backoff * attempt, ct).ConfigureAwait(false);
            }
        }

        throw new RepositoryException(item.Name);
    }

    public async IAsyncEnumerable<User> StreamAsync()
    {
        foreach (var user in _items.Values.OrderBy(u => u.Id))
        {
            await Task.Yield();
            yield return user;
        }
    }
}

public static class Program
{
    public static string Describe(Role role) => role switch
    {
        Role.Admin => "full access",
        Role.Editor or Role.Viewer => "limited access",
        _ => throw new ArgumentOutOfRangeException(nameof(role), role, null),
    };

    public static async Task Main(string[] args)
    {
        var repo = new UserRepository();
        var seed = new[]
        {
            new User(1, "Ada Lovelace", "ada@example.com") { Roles = new[] { Role.Admin } },
            new User(2, "Grace Hopper") { Roles = new[] { Role.Editor, Role.Viewer } },
        };

        await Task.WhenAll(seed.Select(u => repo.SaveAsync(u)));

        var byRole = seed
            .SelectMany(u => u.Roles, (user, role) => (user, role))
            .GroupBy(x => x.role)
            .ToDictionary(g => g.Key, g => g.Select(x => x.user.Name).ToList());

        foreach (var (role, names) in byRole)
        {
            Console.WriteLine($"{role,-8} => {string.Join(", ", names)} ({Describe(role)})");
        }

        await foreach (var user in repo.StreamAsync())
        {
            Console.WriteLine(user);
        }

        var admins = seed.Count(u => u.HasRole(Role.Admin));
        Console.WriteLine(
            $"{repo.Count} users, {admins} admin(s), args={args.Length}, " +
            $"hex=0x{255:X2}, bin={0b1010}, big={1_000_000L}, dec={3.14m}, sci={3.14e-2:E2}");
    }
}
