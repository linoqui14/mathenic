class MathResult {
  final String id;
  final String question;
  final String solution;
  final String answer;
  final String imagePath; // Changed from imageBase64 to imagePath
  final DateTime timestamp;
  final String subject;

  MathResult({
    required this.id,
    required this.question,
    required this.solution,
    required this.answer,
    required this.imagePath,
    required this.timestamp,
    required this.subject,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'question': question,
      'solution': solution,
      'answer': answer,
      'imagePath': imagePath,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'subject': subject,
    };
  }

  factory MathResult.fromMap(Map<String, dynamic> map) {
    return MathResult(
      id: map['id'],
      question: map['question'],
      solution: map['solution'],
      answer: map['answer'],
      imagePath: map['imagePath'],
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp']),
      subject: map['subject'],
    );
  }
}