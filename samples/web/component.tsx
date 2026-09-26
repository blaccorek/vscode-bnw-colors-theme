import { useCallback, useEffect, useMemo, useState } from "react";

interface TodoItem {
  id: string;
  label: string;
  done: boolean;
}

interface TodoListProps {
  title?: string;
  initial?: TodoItem[];
  onChange?: (items: TodoItem[]) => void;
}

const EMPTY: TodoItem[] = [];

export function TodoList({ title = "Todo", initial = EMPTY, onChange }: TodoListProps) {
  const [items, setItems] = useState<TodoItem[]>(initial);
  const [filter, setFilter] = useState<"all" | "open" | "done">("all");

  const visible = useMemo(
    () =>
      items.filter((item) => {
        if (filter === "open") return !item.done;
        if (filter === "done") return item.done;
        return true;
      }),
    [items, filter],
  );

  const toggle = useCallback((id: string) => {
    setItems((prev) => prev.map((it) => (it.id === id ? { ...it, done: !it.done } : it)));
  }, []);

  useEffect(() => {
    onChange?.(items);
  }, [items, onChange]);

  return (
    <section className="todo" data-filter={filter} aria-label={title}>
      <h2 style={{ fontWeight: 600, marginBottom: "0.5rem" }}>
        {title} <small>({visible.length}/{items.length})</small>
      </h2>

      {visible.length === 0 ? (
        <p className="empty">Nothing here&nbsp;yet.</p>
      ) : (
        <ul>
          {visible.map(({ id, label, done }) => (
            <li key={id} className={done ? "done" : undefined}>
              <label>
                <input type="checkbox" checked={done} onChange={() => toggle(id)} />
                {label}
              </label>
            </li>
          ))}
        </ul>
      )}

      <footer>
        {(["all", "open", "done"] as const).map((value) => (
          <button key={value} disabled={value === filter} onClick={() => setFilter(value)}>
            {value}
          </button>
        ))}
      </footer>
    </section>
  );
}

export default TodoList;
