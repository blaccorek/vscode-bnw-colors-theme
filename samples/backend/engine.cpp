// Sample C++: templates, RAII, smart pointers, lambdas, ranges, concepts.
#include <algorithm>
#include <concepts>
#include <cstdint>
#include <format>
#include <iostream>
#include <memory>
#include <optional>
#include <string>
#include <string_view>
#include <unordered_map>
#include <vector>

namespace bnw::samples {

constexpr std::uint32_t kMaxRetries = 3;
constexpr double kTimeoutSeconds = 5.0;
inline constexpr std::string_view kVersion = "1.4.2";

enum class Role : std::uint8_t { Admin, Editor, Viewer };

struct User {
    std::int64_t id{};
    std::string name;
    std::optional<std::string> email;
    std::vector<Role> roles;

    [[nodiscard]] bool has_role(Role role) const noexcept {
        return std::ranges::find(roles, role) != roles.end();
    }
};

template <typename T>
concept Identifiable = requires(const T& item) {
    { item.id } -> std::convertible_to<std::int64_t>;
};

class RepositoryError : public std::runtime_error {
public:
    explicit RepositoryError(std::string_view key)
        : std::runtime_error(std::format("failed to persist '{}'", key)), key_(key) {}

    [[nodiscard]] const std::string& key() const noexcept { return key_; }

private:
    std::string key_;
};

template <Identifiable T>
class Repository {
public:
    Repository() = default;
    virtual ~Repository() = default;
    Repository(const Repository&) = delete;
    Repository& operator=(const Repository&) = delete;
    Repository(Repository&&) noexcept = default;

    virtual bool validate(const T& item) const = 0;

    void save(T item) {
        if (!validate(item)) {
            throw RepositoryError(std::to_string(item.id));
        }
        items_.insert_or_assign(item.id, std::move(item));
    }

    [[nodiscard]] std::optional<T> get(std::int64_t id) const {
        if (const auto it = items_.find(id); it != items_.end()) {
            return it->second;
        }
        return std::nullopt;
    }

    [[nodiscard]] std::size_t size() const noexcept { return items_.size(); }

protected:
    std::unordered_map<std::int64_t, T> items_;
};

class UserRepository final : public Repository<User> {
public:
    bool validate(const User& user) const override { return !user.name.empty(); }
};

constexpr std::string_view describe(Role role) noexcept {
    switch (role) {
        case Role::Admin:  return "full access";
        case Role::Editor: return "write access";
        case Role::Viewer: return "read access";
    }
    return "unknown";
}

}  // namespace bnw::samples

int main() {
    using namespace bnw::samples;

    auto repo = std::make_unique<UserRepository>();
    std::vector<User> seed{
        {1, "Ada Lovelace", "ada@example.com", {Role::Admin}},
        {2, "Grace Hopper", std::nullopt, {Role::Editor, Role::Viewer}},
    };

    for (auto&& user : seed) {
        repo->save(user);
    }

    const auto admins = std::ranges::count_if(seed, [](const User& u) { return u.has_role(Role::Admin); });
    std::ranges::sort(seed, [](const auto& lhs, const auto& rhs) { return lhs.name < rhs.name; });

    for (const auto& [id, name, email, roles] : seed) {
        std::cout << std::format("#{} {:<15} {}\n", id, name, email.value_or("n/a"));
        for (const auto role : roles) {
            std::cout << "  - " << describe(role) << '\n';
        }
    }

    if (const auto found = repo->get(1); found.has_value()) {
        std::cout << "found: " << found->name << '\n';
    }

    std::cout << std::format("v{} | {} users | {} admins | {:#x} {:b} {:.2e}\n",
                             kVersion, repo->size(), admins, 255u, 10u, kTimeoutSeconds);
    return 0;
}
