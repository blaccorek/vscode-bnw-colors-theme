// Sample Java: records, sealed interfaces, generics, streams, switch patterns.
package io.bnw.samples;

import java.time.Duration;
import java.time.Instant;
import java.util.ArrayList;
import java.util.EnumSet;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.Optional;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.TimeUnit;
import java.util.function.Function;
import java.util.regex.Pattern;
import java.util.stream.Collectors;
import java.util.stream.Stream;

public final class UserService {

    public static final String VERSION = "1.4.2";
    private static final int MAX_RETRIES = 3;
    private static final Duration TIMEOUT = Duration.ofSeconds(5);
    private static final Pattern SLUG = Pattern.compile("[^a-z0-9]+");

    public enum Role {
        ADMIN("Full access"),
        EDITOR("Write access"),
        VIEWER("Read access");

        private final String label;

        Role(String label) {
            this.label = label;
        }

        public String label() {
            return label;
        }

        public boolean isPrivileged() {
            return this == ADMIN;
        }
    }

    public record User(long id, String name, String email, EnumSet<Role> roles) {
        public User {
            Objects.requireNonNull(name, "name");
            if (name.isBlank()) {
                throw new IllegalArgumentException("name must not be blank");
            }
            roles = roles == null ? EnumSet.noneOf(Role.class) : EnumSet.copyOf(roles);
        }

        public User(long id, String name) {
            this(id, name, null, EnumSet.of(Role.VIEWER));
        }

        public String slug() {
            return SLUG.matcher(name.toLowerCase()).replaceAll("-").replaceAll("^-|-$", "");
        }

        public boolean hasRole(Role role) {
            return roles.contains(role);
        }
    }

    public sealed interface Result<T> permits Result.Success, Result.Failure {
        record Success<T>(T value) implements Result<T> {}

        record Failure<T>(Throwable error) implements Result<T> {}
    }

    public static class RepositoryException extends RuntimeException {
        private final String key;

        public RepositoryException(String key, Throwable cause) {
            super("failed to persist '%s'".formatted(key), cause);
            this.key = key;
        }

        public String key() {
            return key;
        }
    }

    private final Map<Long, User> items = new ConcurrentHashMap<>();
    private final String namespace;

    public UserService() {
        this("users");
    }

    public UserService(String namespace) {
        this.namespace = namespace;
    }

    public Result<User> save(User user) {
        Throwable last = null;
        for (int attempt = 1; attempt <= MAX_RETRIES; attempt++) {
            try {
                items.put(user.id(), user);
                return new Result.Success<>(user);
            } catch (RuntimeException e) {
                last = e;
                System.err.printf("attempt %d/%d failed: %s%n", attempt, MAX_RETRIES, e.getMessage());
            }
        }
        return new Result.Failure<>(new RepositoryException(namespace + ":" + user.id(), last));
    }

    public Optional<User> find(long id) {
        return Optional.ofNullable(items.get(id));
    }

    public CompletableFuture<List<User>> saveAll(List<User> users) {
        var futures = users.stream()
                .map(user -> CompletableFuture.supplyAsync(() -> save(user)))
                .toList();

        return CompletableFuture.allOf(futures.toArray(CompletableFuture[]::new))
                .orTimeout(TIMEOUT.toMillis(), TimeUnit.MILLISECONDS)
                .thenApply(ignored -> futures.stream()
                        .map(CompletableFuture::join)
                        .flatMap(result -> switch (result) {
                            case Result.Success<User> s -> Stream.of(s.value());
                            case Result.Failure<User> f -> {
                                System.err.println("dropped: " + f.error().getMessage());
                                yield Stream.<User>empty();
                            }
                        })
                        .collect(Collectors.toCollection(ArrayList::new)));
    }

    public static String describe(Role role) {
        return switch (role) {
            case ADMIN -> "unrestricted";
            case EDITOR, VIEWER -> "restricted: " + role.label();
        };
    }

    public static void main(String[] args) {
        var service = new UserService();
        var seed = List.of(
                new User(1L, "Ada Lovelace", "ada@example.com", EnumSet.of(Role.ADMIN)),
                new User(2L, "Grace Hopper", null, EnumSet.of(Role.EDITOR, Role.VIEWER)));

        var stored = service.saveAll(seed).join();

        Map<Boolean, List<String>> grouped = stored.stream()
                .collect(Collectors.partitioningBy(
                        user -> user.hasRole(Role.ADMIN),
                        Collectors.mapping(User::slug, Collectors.toList())));

        Function<Role, String> labeller = UserService::describe;

        var report = """
                bnw-colors %s
                admins : %s
                others : %s
                roles  : %s
                numbers: %d %d %d %,d %.3e
                started: %s
                """.formatted(
                VERSION,
                grouped.get(true),
                grouped.get(false),
                EnumSet.allOf(Role.class).stream().map(labeller).collect(Collectors.joining("; ")),
                0b1010, 017, 0xFF, 1_000_000, 3.14e-2,
                Instant.EPOCH);

        System.out.print(report);
        service.find(1L).ifPresentOrElse(
                user -> System.out.println("found " + user),
                () -> System.out.println("nothing found"));
    }
}
