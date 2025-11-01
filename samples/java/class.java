class Test {
    public static void main(String[] args) {
        System.out.println("Hello, World!");
    }

    private void unusedMethod() {
        // This method is intentionally left blank
    }

    @SuppressWarnings("unused")
    class InnerClass {
        void innerMethod() {
            System.out.println("Inner class method");
        }
    }
}