//! Sample Rust module: traits, generics, enums, error handling, async, macros.

use std::collections::HashMap;
use std::fmt::{self, Display};
use std::sync::Arc;

use tokio::sync::RwLock;

pub const MAX_RETRIES: u32 = 3;
pub const VERSION: &str = "1.4.2";
static DEFAULT_NAMESPACE: &str = "users";

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum Role {
    Admin,
    Editor,
    Viewer,
}

impl Display for Role {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        let name = match self {
            Role::Admin => "admin",
            Role::Editor => "editor",
            Role::Viewer => "viewer",
        };
        write!(f, "{name}")
    }
}

#[derive(Debug, thiserror::Error)]
pub enum RepoError {
    #[error("user {0} not found")]
    NotFound(u64),
    #[error("invalid name: {name:?}")]
    InvalidName { name: String },
    #[error(transparent)]
    Io(#[from] std::io::Error),
}

#[derive(Debug, Clone, PartialEq)]
pub struct User {
    pub id: u64,
    pub name: String,
    pub email: Option<String>,
    pub roles: Vec<Role>,
}

impl User {
    pub fn new(id: u64, name: impl Into<String>) -> Self {
        Self { id, name: name.into(), email: None, roles: Vec::new() }
    }

    pub fn with_role(mut self, role: Role) -> Self {
        self.roles.push(role);
        self
    }

    pub fn has_role(&self, role: Role) -> bool {
        self.roles.iter().any(|r| *r == role)
    }
}

impl Default for User {
    fn default() -> Self {
        Self::new(0, "anonymous")
    }
}

pub trait Repository {
    type Item;

    fn validate(&self, item: &Self::Item) -> Result<(), RepoError>;

    fn namespace(&self) -> &str {
        DEFAULT_NAMESPACE
    }
}

#[derive(Debug, Default)]
pub struct UserRepository {
    items: Arc<RwLock<HashMap<u64, User>>>,
}

impl Repository for UserRepository {
    type Item = User;

    fn validate(&self, item: &User) -> Result<(), RepoError> {
        if item.name.trim().is_empty() {
            return Err(RepoError::InvalidName { name: item.name.clone() });
        }
        Ok(())
    }
}

impl UserRepository {
    pub async fn save(&self, user: User) -> Result<User, RepoError> {
        self.validate(&user)?;
        let mut guard = self.items.write().await;
        guard.insert(user.id, user.clone());
        Ok(user)
    }

    pub async fn get(&self, id: u64) -> Result<User, RepoError> {
        self.items
            .read()
            .await
            .get(&id)
            .cloned()
            .ok_or(RepoError::NotFound(id))
    }
}

pub fn summarize<'a, I>(users: I) -> String
where
    I: IntoIterator<Item = &'a User>,
{
    let (admins, total) = users
        .into_iter()
        .fold((0_usize, 0_usize), |(a, t), u| (a + u.has_role(Role::Admin) as usize, t + 1));

    format!("{admins}/{total} admins (v{VERSION})")
}

#[macro_export]
macro_rules! users {
    ($($id:expr => $name:expr),* $(,)?) => {{
        vec![$(User::new($id, $name)),*]
    }};
}

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let repo = UserRepository::default();
    let ada = User::new(1, "Ada Lovelace").with_role(Role::Admin);

    repo.save(ada.clone()).await?;
    let fetched = repo.get(1).await?;
    assert_eq!(fetched, ada);

    let batch = users![2 => "Grace Hopper", 3 => "Alan Turing"];
    println!("{} | {:?} | {:#x} {:b} {:e}", summarize(&batch), Role::Viewer, 255_u32, 10_u8, 1234.5_f64);

    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn rejects_blank_names() {
        let repo = UserRepository::default();
        let err = repo.save(User::new(1, "   ")).await.unwrap_err();
        assert!(matches!(err, RepoError::InvalidName { .. }));
    }
}
