// Sample Kotlin: data classes, sealed types, coroutines, extensions, DSLs.
package io.bnw.samples

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.async
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.flow
import kotlinx.coroutines.withContext

const val VERSION: String = "1.4.2"
private const val MAX_RETRIES = 3
private val SLUG_REGEX = Regex("""[^a-z0-9]+""")

enum class Role(val label: String) {
    ADMIN("Full access"),
    EDITOR("Write access"),
    VIEWER("Read access");

    val privileged: Boolean get() = this == ADMIN
}

data class User(
    val id: Long,
    val name: String,
    val email: String? = null,
    val roles: Set<Role> = emptySet(),
) {
    val slug: String by lazy { name.lowercase().replace(SLUG_REGEX, "-").trim('-') }

    fun hasRole(vararg wanted: Role): Boolean = wanted.any { it in roles }
}

sealed interface Result<out T> {
    data class Success<T>(val value: T) : Result<T>
    data class Failure(val error: Throwable) : Result<Nothing>
    data object Pending : Result<Nothing>
}

class RepositoryException(key: String, cause: Throwable? = null) :
    RuntimeException("failed to persist '$key'", cause)

interface Repository<T : Any> {
    suspend fun save(item: T): Result<T>
    suspend fun get(id: Long): T?
}

class UserRepository(private val namespace: String = "users") : Repository<User> {
    private val items = mutableMapOf<Long, User>()

    val size: Int
        get() = items.size

    override suspend fun save(item: User): Result<User> = withContext(Dispatchers.Default) {
        repeat(MAX_RETRIES) { attempt ->
            runCatching {
                require(item.name.isNotBlank()) { "blank name" }
                items[item.id] = item
                return@withContext Result.Success(item)
            }.onFailure { error ->
                println("attempt ${attempt + 1}/$MAX_RETRIES failed: ${error.message}")
            }
        }
        Result.Failure(RepositoryException("$namespace:${item.id}"))
    }

    override suspend fun get(id: Long): User? = items[id]

    fun stream(): Flow<User> = flow {
        items.values.sortedBy(User::id).forEach { emit(it) }
    }
}

fun User.describe(): String = buildString {
    append("#$id ")
    append(name)
    email?.let { append(" <$it>") }
    if (roles.isNotEmpty()) append(roles.joinToString(prefix = " [", postfix = "]") { it.label })
}

inline fun <T> measured(label: String, block: () -> T): T {
    val start = System.nanoTime()
    return try {
        block()
    } finally {
        println("$label took ${(System.nanoTime() - start) / 1_000_000}ms")
    }
}

suspend fun main() = coroutineScope {
    val repo = UserRepository()
    val seed = listOf(
        User(1, "Ada Lovelace", "ada@example.com", setOf(Role.ADMIN)),
        User(2, "Grace Hopper", roles = setOf(Role.EDITOR, Role.VIEWER)),
    )

    val saved = measured("seed") {
        seed.map { user -> async { repo.save(user) } }.map { it.await() }
    }

    saved.forEach { result ->
        when (result) {
            is Result.Success -> println(result.value.describe())
            is Result.Failure -> System.err.println("error: ${result.error.message}")
            Result.Pending -> println("pending…")
        }
    }

    val (admins, others) = seed.partition { it.hasRole(Role.ADMIN) }
    println("v$VERSION | ${repo.size} users | ${admins.size} admins | ${others.map(User::slug)}")
    println("${0b1010} ${0xFF} ${1_000_000L} ${3.14e-2} ${'$'}literal")
}
