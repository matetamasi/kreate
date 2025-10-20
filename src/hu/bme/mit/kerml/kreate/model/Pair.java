package hu.bme.mit.kerml.kreate.model;

public record Pair<K, V>(K k, V v) {
//	private K k;
//	private V v;

//	private Pair(K k, V v) {
//		this.k = k;
//		this.v = v;
//	}
	
	public static <K, V> Pair<K, V> of(K k, V v) {
		return new Pair<>(k, v);
	}

	public K k() {
		return k;
	}
	
	public V v() {
		return v;
	}
	
	@Override
	public String toString() {
		return k.toString() + " -> " + v.toString();
	}
}
